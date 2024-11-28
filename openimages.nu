def main [entry: number] {
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
    let exists = ls extractions | where name == $"extractions/entry_($entrystr).bin.extracted" | length
    if $exists == 0 {
        print "This entry has no content."
    } else if $exists == 1 {
        cd $"extractions/entry_($entrystr).bin.extracted"
        cd (ls | get name | first)
        feh (ls | get name | first)
    }
}