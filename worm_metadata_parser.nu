"" | save -f filenames.txt
"" | save -f descriptions.txt
cd parsed_entry_files 
    | ls 
    | where type == dir 
    | where name =~ entry_
    | get name 
    | each {|dir| cd $dir
            let lines = strings header.bin | lines
            let jpgs = $lines | where (str contains ".jpg")
            if ($jpgs | length) != 0 {
               [($jpgs | first), (char newline)] | str join | save --append ../../filenames.txt
            }
            let pdfs = $lines | where (str contains ".pdf")
            if ($pdfs | length) != 0 {
                [($pdfs | first), (char newline)] | str join | save --append ../../filenames.txt
            }
            let dbs = $lines | where (str contains ".db")
            if ($dbs | length) != 0 {
                let $des = getdes (strings header.bin | lines)
                if ($des | is-not-empty) {
                    [ $des, (char newline)] | str join | save --append ../../descriptions.txt
                }
            }
        }

def getdes [header:list]: nothing -> string {
    if (($header | length) > 0 ) {
        if ($header | first) != "Teeth2" {
            getdes ($header | reject 0)
        } else {
            let nextheader = $header | reject 0
            if (($nextheader | length) > 0 ) {
                return ($nextheader | str join "_" )
            }
        }
    }
 } 