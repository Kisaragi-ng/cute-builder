#!/bin/bash
set -euo pipefail

# variables
project_folder=/home/cutie/cutie

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
    # remove script inject if exist
    if [ -f "$project_folder/themes/hugo-book/layouts/shortcodes/inject$series$chapter.html" ]; then
        logf removing "$project_folder/themes/hugo-book/layouts/shortcodes/inject$series$chapter.html"
        rm -rf "$project_folder/themes/hugo-book/layouts/shortcodes/inject$series$chapter.html"

    fi

    # create directory
    logf creating directory "$project_folder/content/pr/$series/chapter-$chapter"
    mkdir -p "$project_folder"/content/pr/"$series"/chapter-"$chapter"

    logf creating empty index "$project_folder/content/pr/$series/_index.md"
    touch "$project_folder/content/pr/$series/_index.md"

    logf generating "$project_folder/content/pr/$series/chapter-$chapter/_index.md"

    # create _index.md head, and open tabs
    {
        echo "---"
        echo "bookCollapseSection: false"
        echo "weight: $chapter"0
        echo "---"
        echo "{{< inject$series$chapter >}}"
        echo "{{< tabs ""$series"-"$chapter"-"$revision"" >}}"
    } >>"$project_folder/content/pr/$series/chapter-$chapter/_index.md" # group tab open

    # open anno <script> tag
    {
        echo "<script>"
        echo "    window.onload = function () {"
    } >>"$project_folder/themes/hugo-book/layouts/shortcodes/inject$series$chapter.html"
    # create tab entries
    readarray -d '' array0 < <(printf '%s\0' temp/*.png | sort -zV)
    for files in "${array0[@]}"; do
        logf creating tab entries for "$files"
        {
            echo "{{< tab $(basename -s .png "$files") >}}"
            echo "![$series-$(basename -s .png "$files")]($(basename "$files"))"
            echo "{{< /tab >}}"
            echo " "
        } >>"$project_folder/content/pr/$series/chapter-$chapter/_index.md"
        # create anno init entries with template 2
        {
            echo "        anno$(basename -s .png "$files") = Annotorious.init({"
            echo "            image: document.querySelector('img[alt=\"$series-$(basename -s .png "$files")\"]'),"
            cat "$project_folder/content/src/template/anno_2.tpl"
        } >>"$project_folder/themes/hugo-book/layouts/shortcodes/inject$series$chapter.html"
    done
    # insert template 3 after tab entries
    for files in temp/*.png; do
        {
            sed "s/anno\./anno$(basename -s .png "$files")\./g" "$project_folder/content/src/template/anno_3.tpl"
        } >>"$project_folder/themes/hugo-book/layouts/shortcodes/inject$series$chapter.html"
    done
    # close anno <script> tag
    {
        echo "    }"
        echo "</script>"
    } >>"$project_folder/themes/hugo-book/layouts/shortcodes/inject$series$chapter.html"
    # group tab close
    echo "{{< /tabs >}}" >>"$project_folder/content/pr/$series/chapter-$chapter/_index.md"

    # move files
    for files in temp/*.png; do
        logf processing "$files"
        # compress file if it's ≥ 1MB, else just move it right away
        if [[ $(du "$files" | awk '{ print $1 }') -gt 1024 ]]; then
            pngquant --quality=80 --force --strip "$files" --output "$project_folder/content/pr/$series/chapter-$chapter/$(basename "$files")"
        else
            mv "$files" "$project_folder/content/pr/$series/chapter-$chapter/"
        fi
    done

    # housekeeping
    systemctl --user restart hugo.service
    rm -r temp/
    rm /tmp/test.tmp
done
