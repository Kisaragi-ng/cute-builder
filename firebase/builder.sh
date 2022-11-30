#!/bin/bash
set -euo pipefail

# variables
project_folder=/home/cutie/cutie
page_count=1

function sigint() {
    echo -e "SIGINT detected \nExit(2)."
    exit 2
}
trap "sigint" 2

function logf() {
    echo "[log][$(date "+%s")]: ${*}"
}

function sanitize() {
    sed 's/ //g'
    sed 's/\r$//g'
    sed 's/^M//g'
    sed 's/[^a-zA-Z0-9]//'
}

cd /void/playground/builder || exit

for archive in *.zip; do
    logf processing file "$archive"
    7z x -otemp/ "$archive" -y
    # make sure files are in the right level
    find temp/ -maxdepth 1 >/tmp/test.tmp
    if [[ "$(grep -io "png" </tmp/test.tmp | wc -l)" -eq 0 ]]; then
        logf "file not exist in level 1, attempting to move from one level otherwise fail"
        mv -v temp/*/*.* temp/
    fi

    find temp/ -depth -exec rename 's/(.*)\/([^\/]*)/$1\/\L$2/' {} \;
    dos2unix ./temp/chapter.yml
    series="$(grep series <temp/chapter.yml | cut -d ':' -f 2 | sanitize | tr '[:upper:]' '[:lower:]')"
    chapter="$(grep chapter <temp/chapter.yml | cut -d ':' -f 2 | sanitize | tr -dc '0-9')"
    revision="$(grep revision <temp/chapter.yml | cut -d ':' -f 2 | sanitize | tr -dc '0-9')"
    export series
    export chapter
    export revision
    # target path /home/cutie/cutie/content/pr/title-1/chapter-1
    # revision does not have their own folder, so make sure to remove old folder first if any
    if [ -d "$project_folder/content/pr/$series/chapter-$chapter" ]; then
        logf removing "$project_folder/content/pr/$series/chapter-$chapter"
        rm -rf "$project_folder/content/pr/$series/chapter-$chapter"
    fi

    # create chapter directory
    logf creating directory "$project_folder/content/pr/$series/chapter-$chapter"
    mkdir -p "$project_folder"/content/pr/"$series"/chapter-"$chapter"
    # create empty index for series
    logf creating empty index "$project_folder/content/pr/$series/_index.md"
    touch "$project_folder/content/pr/$series/_index.md"

    # create post entries
    readarray -d '' array0 < <(printf '%s\0' temp/*.png | sort -zV)
    for files in "${array0[@]}"; do
        # create folder for each files
        mkdir -p "$project_folder"/content/pr/"$series"/chapter-"$chapter"/"$page_count"

        # create anno inject script;
        # remove script inject if exist
        if [ -f "$project_folder/themes/hugo-book/layouts/shortcodes/inject$series$chapter$page_count.html" ]; then
            logf removing "shortcodes/inject$series$chapter$page_count.html"
            rm -rf "$project_folder/themes/hugo-book/layouts/shortcodes/inject$series$chapter$page_count.html"
        fi
        logf creating "shortcodes/inject$series$chapter$page_count.html"
        {
            sed "s/UNDEFINED/$series-$(basename -s .png "$files")\./g" "$project_folder/content/src/template/firebase.tpl"
        } >>"$project_folder/themes/hugo-book/layouts/shortcodes/inject$series$chapter$page_count.html"

        # create index for each files
        logf current page_count value is $page_count, creating post entries for "$series"/"$chapter"/"$(basename "$files")"
        {
            echo "---"
            echo "bookCollapseSection: false"
            echo "weight: $page_count"0
            echo "---"
            echo "{{< inject$series$chapter$page_count >}}"
            echo "![$series-$(basename -s .png "$files")]($(basename "$files"))"
            echo "{{< button relref="/$((page_count - 1))" >}}Prev{{< /button >}}"
            echo "{{< button relref="/$((page_count + 1))" >}}Next{{< /button >}}"
        } >>"$project_folder"/content/pr/"$series"/chapter-"$chapter"/"$page_count"/_index.md

        # move files
        if [[ $(du "$files" | awk '{ print $1 }') -gt 1024 ]]; then
            pngquant --quality=80 --force --strip "$files" --output "$project_folder"/content/pr/"$series"/chapter-"$chapter"/"$page_count"/"$(basename "$files")"
        else
            mv "$files" "$project_folder"/content/pr/"$series"/chapter-"$chapter"/"$page_count"
        fi

        # iterate page count for next loop
        ((page_count++))
    done

    # cleaning up
    rm -r temp/
    rm /tmp/test.tmp
    systemctl --user restart hugo.service
    sleep 10
    systemctl --user status hugo.service
done
