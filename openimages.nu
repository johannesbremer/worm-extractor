def main [dirname: string] {
    let exists = ls | where name == $dirname | length
    if $exists == 0 {
        print "This entry has no content."
    } else if $exists == 1 {
        cd $dirname
        cd (ls | get name | first)
        feh (ls | get name | first)
    }
}