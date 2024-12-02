def main [
    filename: string
] {
    # Magic Numbers
    const minheaderlen = 200 # Every entry has a header at least this long
    const maxheaderlen = 3072 # Every description is no longer than this
    const headermarker = 'CG PACS FILE HEADER Version 1' # Every entry starts with this string

    if (ls | where name == extractions | length) == 1 {
        rm --recursive extractions/
    }
    if (ls | where name == stdin | length) == 1 {
        rm --recursive stdin/
    }
    mkdir extractions/

    let start = strings --radix=d $filename
        | lines
        | where (str contains $headermarker)
        | str replace $headermarker ''
        | str replace --all ' ' ''
        | into int
        | first 60

    let blob = open $filename
    let blobsize = (ls $filename | get size | first) / 1B | into int

    let cuts = $start 
        | wrap start 
        | merge ($start | skip 1 | append $blobsize | wrap end)

    let metadata = $cuts | par-each --keep-order { |entry|
        let filetype = $blob
            | skip $entry.start
            | take $minheaderlen 
            | strings 
            | lines
            | last

        if (($filetype | str contains ".jpg") or ($filetype | str contains ".pdf")) {
            $blob
                | skip ($entry.start + $minheaderlen)
                | take ($entry.end - $entry.start)
                |./binwalk --stdin --extract --threads 1 --directory $"extractions/($filetype)"
        }

        let filen = {
            filename: none
        } | if (($filetype | str contains ".jpg") or ($filetype | str contains ".pdf")) { 
                update filename {$filetype} 
            }

        let descr = {
            description: none
        } | if ($filetype | str contains ".dbr") {
            update description {
                let $twolists = $blob  
                    | skip $entry.start 
                    | take $maxheaderlen 
                    | strings
                    | lines
                    | split list Teeth2
                
                if (($twolists | length) == 2) {
                    ($twolists | last | str join "_")
                } else {
                    "-"
                }
            }
        }
        
        [$filen $descr]
    }   | flatten
        | where (is-not-empty)

    let $filenames = $metadata | every 2 | flatten
    let $descriptions = $metadata | every 2 --skip | flatten
    
    let joinedfile = $filenames | merge $descriptions
    print $joinedfile
}