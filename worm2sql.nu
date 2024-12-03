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
    if (ls | where name == content | length) == 1 {
        rm --recursive content/
    }
    mkdir content/

    let blob = open $filename
    let blobsize = (ls $filename | get size | first) / 1B | into int

    let start = $blob
        | strings --radix=d
        | lines
        | where (str contains $headermarker)
        | str replace $headermarker ''
        | str replace --all ' ' ''
        | into int

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
                |./binwalk --stdin --quiet --extract --threads 1 --directory $"extractions/($filetype)"
                | ignore
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
        
    mut oscillator = true
    mut fil = []
    mut des = []

    for entry in 0..(($metadata | length) - 1) {
        let rec = $metadata | get $entry 
        mut column = true
        if ($rec | to nuon | str starts-with '{filename: ') {
            $column = true
        } else if ($rec | to nuon | str starts-with '{description: ') {
            $column = false
        }
        if $oscillator and $column {
            $fil = $fil | append $rec.filename
            $oscillator = false
        } else if ($oscillator == false) and ($column == false) {
            $des = $des | append $rec.description
            $oscillator = true
        }
    }
    $fil | wrap filename | merge ($des |wrap description) | print

    
    let joinedfile = $metadata | wrap filename | update filename {print}

    cd extractions/
    ls | get name | par-each { |name|
        cd $name
        if (ls | length) == 2 {
            cd stdin.extracted
            if (ls | length) == 1 {
                cd (ls | first | get name)
                convert image.jpg $"../../../../content/($name).pdf"
            } else if (ls | length) > 1 {
                ls | get name | each { |dir|
                    cd $dir
                    let filename = ls
                        | get modified
                        | format date %s.%f
                    convert image.jpg $"../($filename).pdf"
                }
                pwd | print
            }
        }
    } | ignore
}