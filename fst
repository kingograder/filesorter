#!/usr/bin/env bash

# Строгий режим для безопасности и предсказуемости
# set -e: выход при ошибке
# set -u: выход при использовании необъявленной переменной
# set -o pipefail: выход, если команда в конвейере завершается с ошибкой
set -euo pipefail

# ===================================================================
# Секция: Конфигурация
# Это единственный блок, который нужно редактировать для настройки.
# ===================================================================

# Базовая директория для отсортированных файлов.
# Чтобы убрать лишний уровень вложенности, можно установить: readonly DIR_BASE="."
readonly DIR_BASE="./Sorted"

# Определения путей для категорий
readonly DIR_IMAGES="$DIR_BASE/Images"
readonly DIR_IMAGES_RASTER="$DIR_IMAGES/Raster"
readonly DIR_IMAGES_VECTOR="$DIR_IMAGES/Vector"
readonly DIR_IMAGES_PROJECTS="$DIR_IMAGES/Projects"
readonly DIR_ICONS="$DIR_IMAGES/Icons"
readonly DIR_TEXTURES="$DIR_IMAGES/Textures"
readonly DIR_IMAGES_RAW="$DIR_IMAGES/RAW"
readonly DIR_VIDEOS="$DIR_BASE/Videos"
readonly DIR_VIDEO_PROJECTS="$DIR_VIDEOS/Projects"
readonly DIR_MUSIC="$DIR_BASE/Music"
readonly DIR_AUDIO_PROJECTS="$DIR_MUSIC/Projects"
readonly DIR_DOCUMENTS="$DIR_BASE/Documents"
readonly DIR_DOCUMENTS_TEXT="$DIR_DOCUMENTS/Texts"
readonly DIR_DOCUMENTS_TABLES="$DIR_DOCUMENTS/Tables"
readonly DIR_PRESENTATIONS="$DIR_DOCUMENTS/Presentations"
readonly DIR_EBOOKS="$DIR_DOCUMENTS/Ebooks"
readonly DIR_EXECUTABLES="$DIR_BASE/Executables"
readonly DIR_PACKAGES="$DIR_BASE/Packages"
readonly DIR_TORRENTS="$DIR_BASE/Torrents"
readonly DIR_CODE="$DIR_BASE/Code"
readonly DIR_PYTHON="$DIR_CODE/Python"
readonly DIR_WEB="$DIR_CODE/Web"
readonly DIR_PROJECT_FILES="$DIR_BASE/Projects"
readonly DIR_3D="$DIR_BASE/3D"
readonly DIR_3D_PROJECTS="$DIR_3D/Projects"
readonly DIR_3D_EXCHANGE="$DIR_3D/Exchange"
readonly DIR_CAD="$DIR_BASE/CAD"
readonly DIR_ARCHIVES="$DIR_BASE/Archives"
readonly DIR_FONTS="$DIR_BASE/Fonts"
readonly DIR_VIRTUAL="$DIR_BASE/VirtualMachines"
readonly DIR_OTHER="$DIR_BASE/Other" # Директория для всего остального

# Карта "Путь категории -> Расширения"
# ВАЖНО: Категория DIR_OTHER здесь не указывается, она работает как "умолчание".
declare -rA CATEGORY_TO_EXTENSIONS=(
  ["$DIR_IMAGES_RASTER"]="jpg jpeg jfif jpe jpeg2000 jp2 png gif bmp tiff tif heic heif webp hdr exr dib ppm pgm pbm"
  ["$DIR_IMAGES_VECTOR"]="svg eps ai cdr emf wmf"
  ["$DIR_IMAGES_PROJECTS"]="psd psb xcf kra afdesign afphoto sketch cpt cap procreate cptx"
  ["$DIR_ICONS"]="ico icns icon icl"
  ["$DIR_TEXTURES"]="tga tx dds sbsar"
  ["$DIR_IMAGES_RAW"]="cr2 cr3 nef nrw orf arw pef raf rw2 dng mrw kdc srw"
  ["$DIR_VIDEOS"]="mp4 mkv avi mov webm flv mpg mpeg m4v wmv vob ogv"
  ["$DIR_VIDEO_PROJECTS"]="prproj aep vegsml veg vstp drp mlv mlt pfls fcpxml fcpx project davinci"
  ["$DIR_MUSIC"]="mp3 wav flac aac m4a ogg wma opus aiff aif mid midi"
  ["$DIR_AUDIO_PROJECTS"]="als flp ptf ptf64 logicpro aup xrns prj"
  ["$DIR_DOCUMENTS_TEXT"]="txt md doc docx rtf tex html htm xml"
  ["$DIR_DOCUMENTS_TABLES"]="xls xlsx xlsm csv ods db sqlite sql mdb accdb"
  ["$DIR_PRESENTATIONS"]="ppt pptx odp key"
  ["$DIR_EBOOKS"]="epub mobi azw3"
  ["$DIR_EXECUTABLES"]="exe bin sh run runme app AppImage jar dll so bat cmd com"
  ["$DIR_PACKAGES"]="deb rpm apk msi pkg dmg snap flatpak appimage"
  ["$DIR_TORRENTS"]="torrent magnet"
  ["$DIR_CODE"]="c cpp h hpp java class cs go rs swift kotlin rb php pl js jsx ts tsx json yaml yml toml"
  ["$DIR_PYTHON"]="py pyc pyo pyd ipynb"
  ["$DIR_WEB"]="html htm css js jsx tsx mjs map manifest webmanifest"
  ["$DIR_PROJECT_FILES"]="sln vcsproj vbproj gradle pom.xml package.json Makefile CMakeLists.txt workspace code-workspace"
  ["$DIR_3D_PROJECTS"]="blend max c4d mb ma 3ds bdoc zprj scene xrscene mtlx"
  ["$DIR_3D_EXCHANGE"]="obj fbx dae stl ply glb gltf 3mf off wrl x3d"
  ["$DIR_CAD"]="sldprt sldasm slddrw prt asm step stp iges igs dwg dxf catpart catproduct catdrawing 3dm"
  ["$DIR_ARCHIVES"]="zip rar 7z tar gz tgz bz2 tbz xz txz lz4 lzma cab iso img vhd vhdx"
  ["$DIR_FONTS"]="ttf otf woff woff2 pfb afm"
  ["$DIR_VIRTUAL"]="vmdk vdi qcow2 ova ovf img qcow qcow2"
)

# ===================================================================
# Секция: Глобальные переменные
# ===================================================================

# Флаги состояния, управляемые аргументами
is_recursive=0
is_date_sort=0
is_copy_mode=0
is_quiet=0
skip_prompt=0
output_dir=""
exclusions=()

# Счетчики для итоговой статистики
files_processed=0
dirs_created=0
errors_count=0

# Строки для логов, меняются при выборе режима копирования
action_name="Перемещение"
action_past_tense="Перемещено"

# Путь к самому скрипту, чтобы он не отсортировал сам себя
script_path=""

# ===================================================================
# Секция: Функции
# ===================================================================

# Функция: show_help
# Показывает справку по использованию скрипта.
# Функция: show_help
# Показывает справку по использованию скрипта.
show_help() {
  cat << EOF

Универсальный скрипт для сортировки файлов.

Скрипт сортирует файлы в $DIR_BASE.

Использование: $(basename "$0") [flags]

Флаги:
-o, --output DIR  Сортировать файлы в указанную директорию DIR.
-r, --recursive   Включить рекурсивный поиск файлов в поддиреториях.
-d, --date        Сортировать файлы по дате.
-c, --copy        Копировать файлы вместо перемещения.
-a, --avoid PAT   Исключить файлы или директории (например, -a "*.tmp").
-q, --quiet       Тихий режим.
-y, --yes         Согласиться с выполнением.
-h, --help        Показать это справочное сообщение.

EOF
  exit 0
}

# Функция: log_info
# Выводит информационное сообщение (если не включен тихий режим).
log_info() {
    if [[ "$is_quiet" -eq 0 ]]; then echo "$@"; fi
}

# Функция: log_error
# Выводит сообщение об ошибке в стандартный поток ошибок (stderr).
log_error() {
    echo "ОШИБКА: $@" >&2
}

# Функция: generate_ext_to_category_map
# Создает "обратную" карту "расширение -> категория" для быстрого поиска.
generate_ext_to_category_map() {
    declare -gA ext_to_category_map
    for category in "${!CATEGORY_TO_EXTENSIONS[@]}"; do
        read -r -a extensions_array <<< "${CATEGORY_TO_EXTENSIONS[$category]}"
        for ext in "${extensions_array[@]}"; do
            ext_to_category_map["$ext"]="$category"
        done
    done
}

# Функция: setup_target_directories
# Динамически создает полные пути ко всем целевым директориям.
setup_target_directories() {
    local base_dest_dir="$1"
    declare -gA category_dirs

    # Создаем пути для всех категорий, указанных в конфигурации
    for category_path in "${!CATEGORY_TO_EXTENSIONS[@]}"; do
        category_dirs["$category_path"]="$base_dest_dir/$category_path"
    done

    # Отдельно добавляем путь для 'Other', так как его нет в основном списке
    category_dirs["$DIR_OTHER"]="$base_dest_dir/$DIR_OTHER"
}

# Функция: process_file
# Основная логика обработки одного файла.
process_file() {
    local file_path="$1"

    # Пропускаем символические ссылки
    if [[ -L "$file_path" ]]; then
        log_info "Пропущен симлинк: $file_path"
        return
    fi

    local filename; filename=$(basename -- "$file_path")
    local extension; extension="${filename##*.}"
    local category

    # Определяем категорию файла
    if [[ "$extension" == "$filename" ]]; then
        # Файл без расширения -> Other
        category="$DIR_OTHER"
    else
        extension="${extension,,}" # Приводим расширение к нижнему регистру
        # Ищем категорию в карте. Если не найдено, используем $DIR_OTHER по умолчанию.
        category="${ext_to_category_map[$extension]:-$DIR_OTHER}"
    fi

    # Формируем конечный путь
    local dest_dir="${category_dirs[$category]}"
    if [[ "$is_date_sort" -eq 1 ]]; then
        local date_subdir; date_subdir=$(date -r "$file_path" "+%Y/%m")
        dest_dir="$dest_dir/$date_subdir"
    fi

    # Создаем директорию, если она не существует
    if [[ ! -d "$dest_dir" ]]; then
        if mkdir -p "$dest_dir"; then
            ((++dirs_created))
            log_info "Создана директория: $dest_dir"
        else
            log_error "Не удалось создать директорию: $dest_dir"
            ((++errors_count)); return
        fi
    fi

    # Проверяем на конфликт имен и генерируем новое, если нужно
    local dest_path="$dest_dir/$filename"
    if [[ -e "$dest_path" ]]; then
        local base_name="${filename%.*}"
        local ext_part=""; if [[ "$filename" == *.* ]]; then ext_part=".${filename##*.}"; fi
        local counter=1
        while [[ -e "${dest_dir}/${base_name}_${counter}${ext_part}" ]]; do
            ((++counter))
        done
        dest_path="${dest_dir}/${base_name}_${counter}${ext_part}"
        log_info "Файл '$filename' существует, новое имя: '$(basename "$dest_path")'"
    fi

    # Выполняем действие: перемещение или копирование
    local cmd_to_run=mv
    if [[ "$is_copy_mode" -eq 1 ]]; then cmd_to_run=cp; fi

    if "$cmd_to_run" -n "$file_path" "$dest_path"; then
        log_info "${action_past_tense}: $file_path -> $dest_path"
        ((++files_processed))
    else
        log_error "Не удалось обработать $file_path"
        ((++errors_count))
    fi
}

# ===================================================================
# Секция: Основная логика выполнения
# ===================================================================

# Шаг 1: Первоначальные проверки
if [[ "$(pwd)" == "/" ]]; then
    log_error "Запуск из корневой директории (/) запрещен."
    exit 1
fi
script_path=$(realpath "$0")

# Шаг 2: Парсинг аргументов командной строки
while getopts ":o:rdca:qyh" opt; do
    case $opt in
        o) output_dir="$OPTARG" ;;
        r) is_recursive=1 ;;
        d) is_date_sort=1 ;;
        c) is_copy_mode=1; action_name="Копирование"; action_past_tense="Скопировано" ;;
        a) exclusions+=("$OPTARG") ;;
        q) is_quiet=1 ;;
        y) skip_prompt=1 ;;
        h) show_help ;;
        \?) log_error "Неверный флаг: -$OPTARG"; exit 1 ;;
        :) log_error "Флаг -$OPTARG требует аргумент."; exit 1 ;;
    esac
done

# Шаг 3: Инициализация
generate_ext_to_category_map

base_dest_dir="."
dest_type_description="Cортировка в '$(pwd)'"
if [[ -n "$output_dir" ]]; then
    base_dest_dir="$output_dir"
    dest_type_description="Сортировка в указанную директорию '$output_dir'"
fi

setup_target_directories "$base_dest_dir"

# Шаг 4: Поиск файлов
log_info "Анализ файлов для сортировки..."
find_args=(".")
if [[ "$is_recursive" -eq 0 ]]; then find_args+=("-maxdepth" "1"); fi
find_args+=("-type" "f")
find_args+=("-not" "-path" "./$(basename "$script_path")") # Исключаем сам скрипт
for pattern in "${exclusions[@]}"; do find_args+=("-not" "-path" "./$pattern"); done

mapfile -t -d '' files_to_process < <(find "${find_args[@]}" -print0)
file_count=${#files_to_process[@]}

if [[ "$file_count" -eq 0 ]]; then
    log_info "Не найдено файлов для обработки."
    exit 0
fi

# Шаг 5: Сводка и подтверждение (если не пропущено)
if [[ "$skip_prompt" -eq 0 ]]; then
    cat << EOF

Действие:               $action_name
Источник:               $(pwd)
Назначение:             $dest_type_description
Рекурсивный поиск:      $([[ "$is_recursive" -eq 1 ]] && echo "Да" || echo "Нет")
Сортировка по дате:     $([[ "$is_date_sort" -eq 1 ]] && echo "Да" || echo "Нет")

Найдено для обработки:  $file_count файлов.
EOF
    read -p "Начать? (y/[N]) " -r reply
    echo
    case "$reply" in
        [YyДд]) log_info "Начинаем..." ;;
        *) echo "Операция отменена."; exit 1 ;;
    esac
fi

# Шаг 6: Основной цикл обработки файлов
for file_path in "${files_to_process[@]}"; do
    if [[ -f "$file_path" ]]; then
        process_file "${file_path#./}"
    fi
done

# Шаг 7: Финальный отчет
cat << EOF

Операция завершена.

Обработано файлов:         $files_processed
Создано новых директорий:  $dirs_created
Ошибок:                    $errors_count

EOF
