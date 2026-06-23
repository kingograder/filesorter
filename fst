#!/usr/bin/env bash

# Strict mode for safety and predictability
set -euo pipefail

# ===================================================================
# Section: Configuration (Relative paths)
# ===================================================================

readonly DIR_IMAGES_RASTER="Images/Raster"
readonly DIR_IMAGES_VECTOR="Images/Vector"
readonly DIR_IMAGES_PROJECTS="Images/Projects"
readonly DIR_ICONS="Images/Icons"
readonly DIR_TEXTURES="Images/Textures"
readonly DIR_IMAGES_RAW="Images/RAW"
readonly DIR_VIDEOS="Videos"
readonly DIR_VIDEO_PROJECTS="Videos/Projects"
readonly DIR_MUSIC="Music"
readonly DIR_AUDIO_PROJECTS="Music/Projects"
readonly DIR_DOCUMENTS_TEXT="Documents/Texts"
readonly DIR_DOCUMENTS_TABLES="Documents/Tables"
readonly DIR_PRESENTATIONS="Documents/Presentations"
readonly DIR_EBOOKS="Documents/Ebooks"
readonly DIR_EXECUTABLES="Executables"
readonly DIR_PACKAGES="Packages"
readonly DIR_TORRENTS="Torrents"
readonly DIR_CODE="Code"
readonly DIR_PYTHON="Code/Python"
readonly DIR_WEB="Code/Web"
readonly DIR_PROJECT_FILES="Projects"
readonly DIR_3D_PROJECTS="3D/Projects"
readonly DIR_3D_EXCHANGE="3D/Exchange"
readonly DIR_CAD="CAD"
readonly DIR_ARCHIVES="Archives"
readonly DIR_FONTS="Fonts"
readonly DIR_VIRTUAL="VirtualMachines"
readonly DIR_OTHER="Other"

declare -rA CATEGORY_TO_EXTENSIONS=(
  ["$DIR_IMAGES_RASTER"]="jpg jpeg jfif jpe jpeg2000 jp2 png gif bmp tiff tif heic heif webp hdr exr dib ppm pgm pbm avif jxl"
  ["$DIR_IMAGES_VECTOR"]="svg eps ai cdr emf wmf vsdx vsd"
  ["$DIR_IMAGES_PROJECTS"]="psd psb xcf kra afdesign afphoto sketch cpt cap procreate cptx fig xd"
  ["$DIR_ICONS"]="ico icns icon icl"
  ["$DIR_TEXTURES"]="tga tx dds sbsar"
  ["$DIR_IMAGES_RAW"]="cr2 cr3 nef nrw orf arw pef raf rw2 dng mrw kdc srw"
  ["$DIR_VIDEOS"]="mp4 mkv avi mov webm flv mpg mpeg m4v wmv vob ogv 3gp 3g2 mts m2ts ts rm rmvb asf"
  ["$DIR_VIDEO_PROJECTS"]="prproj aep vegsml veg vstp drp mlv mlt pfls fcpxml fcpx project davinci"
  ["$DIR_MUSIC"]="mp3 wav flac aac m4a ogg wma opus aiff aif mid midi dsf dff wv ape tak"
  ["$DIR_AUDIO_PROJECTS"]="als flp ptf ptf64 logicpro aup xrns prj"
  ["$DIR_DOCUMENTS_TEXT"]="txt md doc docx rtf tex html htm xml pdf odt pages wpd"
  ["$DIR_DOCUMENTS_TABLES"]="xls xlsx xlsm csv ods db sqlite sql mdb accdb numbers tsv parquet feather"
  ["$DIR_PRESENTATIONS"]="ppt pptx odp key ppsx pps"
  ["$DIR_EBOOKS"]="epub mobi azw3"
  ["$DIR_EXECUTABLES"]="exe bin sh run runme app AppImage jar dll so bat cmd com ps1 psm1 vbs vbe wsf bash zsh fish csh ksh"
  ["$DIR_PACKAGES"]="deb rpm apk msi pkg dmg snap flatpak appimage whl egg gem nupkg flatpakref"
  ["$DIR_TORRENTS"]="torrent magnet"
  ["$DIR_CODE"]="c cpp h hpp java class cs go rs swift kotlin rb php pl js jsx ts tsx json yaml yml toml lua r m jl scala ex exs hs dart vue svelte astro"
  ["$DIR_PYTHON"]="py pyc pyo pyd ipynb"
  ["$DIR_WEB"]="html htm css js jsx tsx mjs map manifest webmanifest wasm wat"
  ["$DIR_PROJECT_FILES"]="sln vcsproj vbproj gradle pom.xml package.json Makefile CMakeLists.txt workspace code-workspace ini cfg conf env lock"
  ["$DIR_3D_PROJECTS"]="blend max c4d mb ma 3ds bdoc zprj scene xrscene mtlx hip hipnc nk"
  ["$DIR_3D_EXCHANGE"]="obj fbx dae stl ply glb gltf 3mf off wrl x3d usd usda usdc usdz abc"
  ["$DIR_CAD"]="sldprt sldasm slddrw prt asm step stp iges igs dwg dxf catpart catproduct catdrawing 3dm ifc rvt rfa skp"
  ["$DIR_ARCHIVES"]="zip rar 7z tar gz tgz bz2 tbz xz txz lz4 lzma cab iso img vhd vhdx zst cpio lzh lha sit"
  ["$DIR_FONTS"]="ttf otf woff woff2 pfb afm eot pfa"
  ["$DIR_VIRTUAL"]="vmdk vdi qcow2 ova ovf img qcow qcow2"
)

# ===================================================================
# Section: Global Variables
# ===================================================================

is_recursive=0
is_date_sort=0
is_copy_mode=0
is_quiet=0
skip_prompt=0
is_user_dir=0
input_dir=""
output_dir=""
exclusions=()

files_processed=0
dirs_created=0
errors_count=0

action_name="Moving"
action_past_tense="Moved"

script_path=""

# ===================================================================
# Section: Functions
# ===================================================================

show_help() {
  cat << EOF

Universal script for file sorting.

Usage: $(basename "$0") [flags]

Flags:
-i DIR   Specify the input directory to sort files from.
-o DIR   Sort files into the specified directory DIR.
-u       Sort files into the user's home directory (~/Sorted), overrides -o.
-r       Enable recursive file search in subdirectories.
-d       Sort files by date.
-c       Copy files instead of moving them.
-a PAT   Exclude files by pattern (e.g., -a "*.tmp").
-q       Quiet mode.
-y       Agree to execution (skip prompt).
-h       Show this help message.

EOF
  exit 0
}

log_info() {
    if [[ "$is_quiet" -eq 0 ]]; then echo "$@"; fi
}

log_error() {
    echo "ERROR: $*" >&2
}

generate_ext_to_category_map() {
    declare -gA ext_to_category_map
    for category in "${!CATEGORY_TO_EXTENSIONS[@]}"; do
        read -r -a extensions_array <<< "${CATEGORY_TO_EXTENSIONS[$category]}"
        for ext in "${extensions_array[@]}"; do
            ext_to_category_map["$ext"]="$category"
        done
    done
}

setup_target_directories() {
    local base_dest_dir="$1"
    declare -gA category_dirs

    for category_path in "${!CATEGORY_TO_EXTENSIONS[@]}"; do
        category_dirs["$category_path"]="$base_dest_dir/$category_path"
    done
    category_dirs["$DIR_OTHER"]="$base_dest_dir/$DIR_OTHER"
}

process_file() {
    local file_path="$1"

    # Reliable exclusion of the script itself
    if [[ "$(realpath "$file_path" 2>/dev/null)" == "$script_path" ]]; then
        return
    fi

    if [[ -L "$file_path" ]]; then
        log_info "Skipped symlink: $file_path"
        return
    fi

    local filename; filename=$(basename -- "$file_path")
    local extension; extension="${filename##*.}"
    local category

    if [[ "$extension" == "$filename" ]]; then
        category="$DIR_OTHER"
    else
        extension="${extension,,}"
        category="${ext_to_category_map[$extension]:-$DIR_OTHER}"
    fi

    local dest_dir="${category_dirs[$category]}"
    if [[ "$is_date_sort" -eq 1 ]]; then
        local date_subdir; date_subdir=$(date -r "$file_path" "+%Y/%m")
        dest_dir="$dest_dir/$date_subdir"
    fi

    if [[ ! -d "$dest_dir" ]]; then
        if mkdir -p "$dest_dir"; then
            ((++dirs_created))
            log_info "Created directory: $dest_dir"
        else
            log_error "Failed to create directory: $dest_dir"
            ((++errors_count)); return
        fi
    fi

    local dest_path="$dest_dir/$filename"
    if [[ -e "$dest_path" ]]; then
        local base_name="${filename%.*}"
        local ext_part=""; if [[ "$filename" == *.* ]]; then ext_part=".${filename##*.}"; fi
        local counter=1
        while [[ -e "${dest_dir}/${base_name}_${counter}${ext_part}" ]]; do
            ((++counter))
        done
        dest_path="${dest_dir}/${base_name}_${counter}${ext_part}"
        log_info "File '$filename' exists, new name: '$(basename "$dest_path")'"
    fi

    local cmd_to_run="mv"
    if [[ "$is_copy_mode" -eq 1 ]]; then cmd_to_run="cp"; fi

    if "$cmd_to_run" -n "$file_path" "$dest_path"; then
        log_info "${action_past_tense}: $file_path -> $dest_path"
        ((++files_processed))
    else
        log_error "Failed to process $file_path"
        ((++errors_count))
    fi
}

# ===================================================================
# Section: Main Execution Logic
# ===================================================================

original_pwd="$(pwd)"
script_path=$(realpath "$0")

while getopts ":i:o:rdca:qyuh" opt; do
    case $opt in
        i) input_dir="$OPTARG" ;;
        o) output_dir="$OPTARG" ;;
        u) is_user_dir=1 ;;
        r) is_recursive=1 ;;
        d) is_date_sort=1 ;;
        c) is_copy_mode=1; action_name="Copying"; action_past_tense="Copied" ;;
        a) exclusions+=("$OPTARG") ;;
        q) is_quiet=1 ;;
        y) skip_prompt=1 ;;
        h) show_help ;;
        \?) log_error "Invalid flag: -$OPTARG"; exit 1 ;;
        :) log_error "Flag -$OPTARG requires an argument."; exit 1 ;;
    esac
done
shift $((OPTIND -1))

generate_ext_to_category_map

# Determine source directory
if [[ -n "$input_dir" ]]; then
    if [[ ! -d "$input_dir" ]]; then
        log_error "Input directory '$input_dir' does not exist or is not a directory."
        exit 1
    fi
    source_dir="$(realpath "$input_dir")"
else
    source_dir="$original_pwd"
fi

if [[ "$source_dir" == "/" ]]; then
    log_error "Sorting the root directory (/) is forbidden."
    exit 1
fi

# Determine destination directory
if [[ "$is_user_dir" -eq 1 ]]; then
    base_dest_dir="$HOME/Sorted"
    dest_type_description="Sorting into user directory '$base_dest_dir'"
elif [[ -n "$output_dir" ]]; then
    if [[ "$output_dir" != /* ]]; then
        base_dest_dir="$original_pwd/$output_dir"
    else
        base_dest_dir="$output_dir"
    fi
    dest_type_description="Sorting into specified directory '$base_dest_dir'"
else
    base_dest_dir="$original_pwd/Sorted"
    dest_type_description="Sorting into '$base_dest_dir'"
fi

# Change to the source directory for processing
cd "$source_dir"

setup_target_directories "$base_dest_dir"

log_info "Analyzing files for sorting..."
find_args=(".")
if [[ "$is_recursive" -eq 0 ]]; then find_args+=("-maxdepth" "1"); fi
find_args+=("-type" "f")

# Safe handling of exclusions (protection against set -u)
if [[ ${#exclusions[@]} -gt 0 ]]; then
    for pattern in "${exclusions[@]}"; do
        find_args+=("-not" "-name" "$pattern")
    done
fi

mapfile -t -d '' files_to_process < <(find "${find_args[@]}" -print0)
file_count=${#files_to_process[@]}

if [[ "$file_count" -eq 0 ]]; then
    log_info "No files found to process."
    exit 0
fi

if [[ "$skip_prompt" -eq 0 ]]; then
    cat << EOF

Action:               $action_name
Source:               $source_dir
Destination:          $dest_type_description
Recursive search:     $([[ "$is_recursive" -eq 1 ]] && echo "Yes" || echo "No")
Sort by date:         $([[ "$is_date_sort" -eq 1 ]] && echo "Yes" || echo "No")

Found for processing: $file_count files.

EOF
    read -p "Start? (y/[N]) " -r reply
    echo
    case "$reply" in
        [Yy]) log_info "Starting..." ;;
        *) echo "Operation canceled."; exit 1 ;;
    esac
fi

for file_path in "${files_to_process[@]}"; do
    if [[ -f "$file_path" ]]; then
        process_file "${file_path#./}"
    fi
done

cat << EOF

Done.

Files processed:         $files_processed
Directories created:     $dirs_created
Errors:                  $errors_count

EOF
