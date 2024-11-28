mut filenames = []
mut descriptions = []
mut paths = []

for entry in 0..779 {
    mut entrystr = ""
    mut pathentrystr = ""
    if $entry < 10 {
        $entrystr = ["00", ($entry | into string)] | str join
    } else if $entry < 100 {
        $entrystr = ["0", ($entry | into string)] | str join
    } else {
        $entrystr = ($entry | into string) | str join
    }
    cd $"parsed_entry_files/entry_0($entrystr)"
    let lines = strings header.bin | lines
    let jpgs = $lines | where (str contains ".jpg")
    if ($jpgs | length) != 0 {
        $filenames = $filenames | append ($jpgs | first)
        $paths = $paths | append (getfile $entry)
    }
    let pdfs = $lines | where (str contains ".pdf")
    if ($pdfs | length) != 0 {
        $filenames = $filenames | append ($pdfs | first)
        $paths = $paths | append (getfile $entry)
    }
    let dbs = $lines | where (str contains ".db")
    if ($dbs | length) != 0 {
        let $descr = getdes (strings header.bin | lines)
        if ($descr | is-not-empty) {
            $descriptions = $descriptions | append $descr
        }
    }
    cd ../../
}

let joinedfile = $filenames | wrap filenames | merge ($descriptions | wrap descriptions) | merge ($paths | wrap paths)

print $joinedfile

def getdes [header:list]: nothing -> string {
    if (($header | length) > 0) {
        if ($header | first) != "Teeth2" {
            getdes ($header | reject 0)
        } else {
            let nextheader = $header | reject 0
            if (($nextheader | length) > 0) {
                return ($nextheader | str join "_")
            } else {
                return "-"
            }
        }
    }
}

def getfile [entry: number] {
    mut entrystr = ""
    if $entry < 10 {
        $entrystr = ["000", ($entry | into string)] | str join
    } else if $entry < 100 {
        $entrystr = ["00", ($entry | into string)] | str join
    } else if $entry < 1000 {
        $entrystr = ["0", ($entry | into string)] | str join
    } else {
        $entrystr = ($entry | into string)
    }
    cd ../../extractions
    let exists = ls | where name == $"entry_($entrystr).bin.extracted" | length
    if $exists == 1 {
        cd $"entry_($entrystr).bin.extracted"
        cd (ls | get name | first)
        if (ls | get size | first) > 10KiB {
            cd ..
            return $entry
        } else {
            cd ..
            return "Preview"
        }
    } else {
        cd ..
        return "Empty"
    }
}