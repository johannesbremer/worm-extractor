def main [
    filename: string
] {
    mut filenames = []
    mut descriptions = []

    mkdir content

    if (ls | where name == tmp.json | length) == 1 {
        rm tmp.json
    }
    if (ls | where name == tmp.bin | length) == 1 {
        rm tmp.bin
    }
    if (ls | where name == extractions | length) == 1 {
        rm -r extractions
    }

    let $cuts = strings --radix=d $filename
        | lines
        | where (str contains 'CG PACS FILE HEADER Version 1')
        | str replace ' CG PACS FILE HEADER Version 1' ''
        | str replace --all ' ' ''
        | into int

    let blob = open $filename
    let blobsize = (ls $filename | get size | first) / 1B | into int
    let howmanyentries = ($cuts | length)

    for entry in 1..$howmanyentries {
        mut blobend = 0
        if $entry == $howmanyentries {
            $blobend = $blobsize - ($cuts | get ($entry - 1))
        } else {
            $blobend = ($cuts | get $entry) - ($cuts | get ($entry - 1))
        }
        let entryblob = $blob 
            | skip ($cuts | get ($entry - 1))
            | take $blobend

        $entryblob | save tmp.bin
        binwalk --quiet --extract --log tmp.json tmp.bin
        let binwalklog = open tmp.json
        rm tmp.json tmp.bin 
        if (ls extractions | where name == extractions/tmp.bin | length) == 1 {
            rm extractions/tmp.bin
        }

        let $contentstart = $binwalklog | get Analysis | get file_map | first | get offset
        mut headerend = 0
        if ($contentstart | length) > 0 {
            $headerend = $contentstart | first
        } else {
            $headerend = $blobend
        }

        let $header = $entryblob | take $headerend | strings | lines
        let extractionpath = "extractions/tmp.bin.extracted"

        let jpg = $header | where (str contains ".jpg")
        if ($jpg | length) != 0 {
            $filenames = $filenames | append $jpg
            let dir = ["content/", ($jpg | first)] | str join
            if (ls extractions | where name == $extractionpath | length) == 1 {
                cp --force --verbose --recursive $extractionpath $dir
            }
        }

        let pdf = $header | where (str contains ".pdf")
        if ($pdf | length) != 0 {
            $filenames = $filenames | append $pdf
            let dir = ["content/", ($pdf | first)] | str join
            if (ls extractions | where name == $extractionpath | length) == 1 {
                cp --force --verbose --recursive $extractionpath $dir
            }
        }

        let dbs = $header | where (str contains ".db")
        if ($dbs | length) != 0 {
            mut $descr = ""
            let $twolists = $header | split list Teeth2
            if (($twolists | length) == 2) {
                $descr = ($twolists | last | str join "_")
            } else {
                $descr = "-"
            }
            $descriptions = $descriptions | append $descr
        }
        
        if (ls extractions | where name == $extractionpath | length) == 1 {
            rm --recursive $extractionpath
        }
    }
    rm --recursive extractions/
    let joinedfile = $filenames | wrap filenames | merge ($descriptions | wrap descriptions)
    $joinedfile | print
}
