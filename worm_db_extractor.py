import os
import json
import subprocess

def process_entry(entry_file, output_dir, binwalk_exe='binwalk'):
    """
    Process an individual entry using binwalk, organizing metadata and extracted files.
    """
    entry_name = os.path.splitext(os.path.basename(entry_file))[0]
    entry_output_dir = os.path.join(output_dir, entry_name)
    os.makedirs(entry_output_dir, exist_ok=True)

    # Run binwalk on the entry file
    log_path = os.path.join(entry_output_dir, 'log.json')
    binwalk_cmd = [binwalk_exe, '-e', entry_file, '-l', log_path]

    # Ensure `log.json` can be overwritten
    if os.path.exists(log_path):
        os.remove(log_path)

    subprocess.run(binwalk_cmd, check=True)

    # Parse the binwalk log.json
    if not os.path.exists(log_path):
        print(f"Warning: No log.json produced for {entry_file}")
        return

    with open(log_path, 'r') as log_file:
        log_data = json.load(log_file)

    # Extract metadata and organize files
    with open(entry_file, 'rb') as f:
        entry_data = f.read()

    file_map = log_data[0].get('Analysis', {}).get('file_map', [])

    # Save entry metadata (header, footer, and between sections)
    save_entry_metadata(entry_data, file_map, entry_output_dir)

    # Move extracted files into the entry directory
    binwalk_output_dir = os.path.join(os.path.dirname(entry_file) + f'_{entry_name}.extracted')
    if os.path.exists(binwalk_output_dir):
        for extracted_file in os.listdir(binwalk_output_dir):
            os.rename(
                os.path.join(binwalk_output_dir, extracted_file),
                os.path.join(entry_output_dir, extracted_file)
            )
        os.rmdir(binwalk_output_dir)  # Cleanup temporary binwalk folder

def save_entry_metadata(entry_data, file_map, entry_output_dir):
    """
    Save metadata (header, between sections, footer) for an entry.
    """
    offsets = [0] + [entry['offset'] for entry in file_map]
    end_offsets = [entry['offset'] + entry['size'] for entry in file_map]
    offsets.append(len(entry_data))

    # Save header
    header_start = 0
    header_end = file_map[0]['offset'] if file_map else len(entry_data)
    with open(os.path.join(entry_output_dir, 'header.bin'), 'wb') as header_out:
        header_out.write(entry_data[header_start:header_end])

    # Save between files (if any)
    for i in range(len(file_map) - 1):
        between_start = end_offsets[i]
        between_end = file_map[i + 1]['offset']
        with open(os.path.join(entry_output_dir, f'between-{i:02d}.bin'), 'wb') as between_out:
            between_out.write(entry_data[between_start:between_end])

    # Save footer
    footer_start = end_offsets[-1] if file_map else 0
    footer_end = len(entry_data)
    with open(os.path.join(entry_output_dir, 'footer.bin'), 'wb') as footer_out:
        footer_out.write(entry_data[footer_start:footer_end])


def process_database(file_path, output_dir, binwalk_exe='binwalk'):
    """
    Split the database into entries and process each entry.
    """
    split_dir = os.path.join(output_dir, 'split_entries')
    os.makedirs(split_dir, exist_ok=True)

    # Split the database into entries
    split_worm_database(file_path, split_dir, 'CG PACS FILE HEADER Version')

    # Process each entry
    for entry_file in os.listdir(split_dir):
        process_entry(os.path.join(split_dir, entry_file), output_dir, binwalk_exe)

def split_worm_database(file_path, output_dir, header):
    """
    Split the database file into individual entries based on a header marker.
    """
    header_bytes = header.encode('utf-8')
    os.makedirs(output_dir, exist_ok=True)

    with open(file_path, 'rb') as f:
        data = f.read()

    positions = []
    current_pos = 0
    while (current_pos := data.find(header_bytes, current_pos)) != -1:
        positions.append(current_pos)
        current_pos += len(header_bytes)

    for i in range(len(positions)):
        start = positions[i]
        end = positions[i + 1] if i + 1 < len(positions) else len(data)
        entry_data = data[start:end]

        entry_file = os.path.join(output_dir, f'entry_{i:04d}.bin')
        with open(entry_file, 'wb') as out_file:
            out_file.write(entry_data)

# Main script
file_path = 'FILENAME-HERE.bin'  # Path to the WORM database
output_dir = 'parsed_entry_files'  # Base output directory
binwalk_exe = 'binwalk'  # Path to binwalk executable

process_database(file_path, output_dir, binwalk_exe)
