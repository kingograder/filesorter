#!/usr/bin/env bash

# set -e: немедленно выйти, если команда завершается с ошибкой.
# set -u: выйти при использовании необъявленной переменной.
# set -o pipefail: вернуть ненулевой статус, если любая команда в конвейере (pipe)
#                  завершается с ошибкой.
set -euo pipefail

# ===================================================================================
#                               СЕКЦИЯ: Конфигурация
# ===================================================================================
# ЕДИНСТВЕННЫЙ ИСТОЧНИК ПРАВДЫ. Редактируйте этот блок для настройки.
# Логика скрипта автоматически адаптируется под эти данные.

# --- Основные названия директорий (используются как ключи в массиве ниже) ---
readonly DIR_BASE="Sorted"
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
readonly DIR_OTHER="$DIR_BASE/Other"

# --- Карта "Путь категории -> Расширения" ---
declare -rA CATEGORY_TO_EXTENSIONS=(
  # Растровые изображения
  ["$DIR_IMAGES_RASTER"]="jpg jpeg jfif jpe jpeg2000 jp2 png gif bmp tiff tif heic heif webp hdr exr dib ppm pgm pbm"
  # Векторные
  ["$DIR_IMAGES_VECTOR"]="svg eps ai cdr emf wmf"
  # Графические проекты
  ["$DIR_IMAGES_PROJECTS"]="psd psb xcf kra afdesign afphoto sketch cpt cap procreate cptx"
  # Иконки
  ["$DIR_ICONS"]="ico icns icon icl"
  # Текстуры и материалы
  ["$DIR_TEXTURES"]="tga tx dds sbsar"
  # RAW форматы фотоаппаратов
  ["$DIR_IMAGES_RAW"]="cr2 cr3 nef nrw orf arw pef raf rw2 dng mrw kdc srw"

  # Видео
  ["$DIR_VIDEOS"]="mp4 mkv avi mov webm flv mpg mpeg m4v wmv vob ogv"
  # Проекты видео
  ["$DIR_VIDEO_PROJECTS"]="prproj aep vegsml veg vstp drp mlv mlt pfls fcpxml fcpx project davinci"

  # Музыка / аудио
  ["$DIR_MUSIC"]="mp3 wav flac aac m4a ogg wma opus aiff aif mid midi"
  # Проекты аудио / DAW
  ["$DIR_AUDIO_PROJECTS"]="als flp ptf ptf64 logicpro aup xrns prj"

  # Документы текстовые
  ["$DIR_DOCUMENTS_TEXT"]="txt md doc docx rtf tex html htm xml"
  # Таблицы / базы
  ["$DIR_DOCUMENTS_TABLES"]="xls xlsx xlsm csv ods db sqlite sql mdb accdb"
  # Презентации
  ["$DIR_PRESENTATIONS"]="ppt pptx odp key"
  # Электронные книги
  ["$DIR_EBOOKS"]="epub mobi azw3"

  # Исполняемые
  ["$DIR_EXECUTABLES"]="exe bin sh run runme app AppImage jar dll so bat cmd com"
  # Пакеты
  ["$DIR_PACKAGES"]="deb rpm apk msi pkg dmg snap flatpak appimage"
  # Торренты
  ["$DIR_TORRENTS"]="torrent magnet"

  # Кодовые файлы
  ["$DIR_CODE"]="c cpp h hpp java class cs go rs swift kotlin rb php pl js jsx ts tsx json yaml yml toml"
  ["$DIR_PYTHON"]="py pyc pyo pyd ipynb"
  ["$DIR_WEB"]="html htm css js jsx tsx mjs map manifest webmanifest"
  ["$DIR_PROJECT_FILES"]="sln vcsproj vbproj gradle pom.xml package.json Makefile CMakeLists.txt workspace code-workspace"

  # 3D
  ["$DIR_3D_PROJECTS"]="blend max c4d mb ma 3ds bdoc zprj scene xrscene mtlx"
  ["$DIR_3D_EXCHANGE"]="obj fbx dae stl ply glb gltf 3mf off wrl x3d"
  # CAD
  ["$DIR_CAD"]="sldprt sldasm slddrw prt asm step stp iges igs dwg dxf catpart catproduct catdrawing 3dm"

  # Архивы
  ["$DIR_ARCHIVES"]="zip rar 7z tar gz tgz bz2 tbz xz txz lz4 lzma cab iso img vhd vhdx"
  # Шрифты
  ["$DIR_FONTS"]="ttf otf woff woff2 pfb afm"
  # Виртуальные машины
  ["$DIR_VIRTUAL"]="vmdk vdi qcow2 ova ovf img qcow qcow2"
  # Прочие
  ["$DIR_OTHER"]="log cfg ini conf bak tmp partial ds_store zotero rdf rdfxml zotero.sqlite thumbs.db"
)

# ===================================================================================
#                             СЕКЦИЯ: Глобальные переменные
# ===================================================================================
is_recursive=0
is_date_sort=0
is_copy_mode=0
is_quiet=0
skip_prompt=0
output_dir=""
exclusions=()
files_processed=0
dirs_created=0
errors_count=0
action_name="Перемещение"
action_past_tense="Перемещено"
script_path=""

# ===================================================================================
#                                 СЕКЦИЯ: Функции
# ===================================================================================
show_help() {
  cat << EOF
Универсальный скрипт для сортировки файлов.

Использование: $(basename "$0") [flags]

По умолчанию сортирует файлы из текущей директории в её же подпапки.

Флаги:
-o, --output DIR  Сортировать файлы в указанную директорию DIR.
-r, --recursive   Включить рекурсивный поиск файлов в поддиректориях.
-d, --date        Сортировать файлы по дате, создавая подпапки ГГГГ/ММ.
-c, --copy        Копировать файлы вместо перемещения.
-a, --avoid PAT   Исключить файлы или директории по шаблону (например, -a "*.tmp"). Можно использовать несколько раз.
-q, --quiet       Тихий режим (скрыть логи обработки каждого файла).
-y, --yes         Пропустить запрос на подтверждение и немедленно начать выполнение.
-h, --help        Показать это справочное сообщение.
EOF
  exit 0
}

log_info() {
    if [[ "$is_quiet" -eq 0 ]]; then echo "$@"; fi
}

log_error() {
    echo "ОШИБКА: $@" >&2
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

# -----------------------------------------------------------------------------------
# Функция: setup_target_directories (НОВАЯ ВЕРСИЯ)
# Назначение: Динамически инициализирует пути к целевым директориям,
#             основываясь исключительно на массиве CATEGORY_TO_EXTENSIONS.
# Аргументы:
#   $1 - Базовая директория для сортировки.
# -----------------------------------------------------------------------------------
setup_target_directories() {
    local base_dest_dir="$1"
    declare -gA category_dirs # -g делает массив глобальным

    # Динамически перебираем все категории, определенные в конфигурации
    for category_path in "${!CATEGORY_TO_EXTENSIONS[@]}"; do
        # Просто соединяем базовый путь и путь категории
        category_dirs["$category_path"]="$base_dest_dir/$category_path"
    done
}

process_file() {
    local file_path="$1"

    if [[ -L "$file_path" ]]; then
        log_info "Пропущен симлинк: $file_path"
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

    # Получаем полный путь назначения из динамически созданного массива
    local dest_dir="${category_dirs[$category]}"
    if [[ "$is_date_sort" -eq 1 ]]; then
        local date_subdir; date_subdir=$(date -r "$file_path" "+%Y/%m")
        dest_dir="$dest_dir/$date_subdir"
    fi

    if [[ ! -d "$dest_dir" ]]; then
        if mkdir -p "$dest_dir"; then
            ((++dirs_created))
            log_info "Создана директория: $dest_dir"
        else
            log_error "Не удалось создать директорию: $dest_dir"
            ((++errors_count))
            return
        fi
    fi

    local dest_path="$dest_dir/$filename"
    if [[ -e "$dest_path" ]]; then
        local base_name="${filename%.*}"
        local ext_part=""
        if [[ "$filename" == *.* ]]; then ext_part=".${filename##*.}"; fi
        local counter=1
        while [[ -e "${dest_dir}/${base_name}_${counter}${ext_part}" ]]; do
            ((++counter))
        done
        dest_path="${dest_dir}/${base_name}_${counter}${ext_part}"
        log_info "Файл '$filename' уже существует, новое имя: '$(basename "$dest_path")'"
    fi

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

# ===================================================================================
#                               СЕКЦИЯ: Основная логика
# ===================================================================================
if [[ "$(pwd)" == "/" ]]; then
    log_error "Запуск из корневой директории (/) запрещен в целях безопасности."
    exit 1
fi
script_path=$(realpath "$0")

# --- Парсинг аргументов (флаг -g удален) ---
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

generate_ext_to_category_map

base_dest_dir="."
dest_type_description="Локальная сортировка в '$(pwd)'"
if [[ -n "$output_dir" ]]; then
    base_dest_dir="$output_dir"
    dest_type_description="Сортировка в указанную директорию '$output_dir'"
fi

# --- ИСПРАВЛЕННЫЙ ВЫЗОВ ФУНКЦИИ ---
# Правильный синтаксис для вызова функции с аргументом
setup_target_directories "$base_dest_dir"

log_info "Анализ файлов для сортировки..."
find_args=(".")
if [[ "$is_recursive" -eq 0 ]]; then find_args+=("-maxdepth" "1"); fi
find_args+=("-type" "f")
find_args+=("-not" "-path" "./$(basename "$script_path")")
for pattern in "${exclusions[@]}"; do find_args+=("-not" "-path" "./$pattern"); done

mapfile -t -d '' files_to_process < <(find "${find_args[@]}" -print0)
file_count=${#files_to_process[@]}

if [[ "$file_count" -eq 0 ]]; then
    log_info "Не найдено файлов для обработки."
    exit 0
fi

if [[ "$skip_prompt" -eq 0 ]]; then
    cat << EOF
--------------------------------------
        Сводка операции
--------------------------------------
Действие:         $action_name
Источник:         $(pwd)
Назначение:       $dest_type_description
Поиск:            $([[ "$is_recursive" -eq 1 ]] && echo "Рекурсивный" || echo "Только в текущей директории")
Сортировка по дате: $([[ "$is_date_sort" -eq 1 ]] && echo "Включена (ГГГГ/ММ)" || echo "Выключена")

Найдено для обработки: $file_count файлов.
--------------------------------------
EOF
    read -p "Начать? (y/n) " -r reply
    echo
    case "$reply" in
        [YyДд]) log_info "Начинаем..." ;;
        *) echo "Операция отменена."; exit 1 ;;
    esac
fi

for file_path in "${files_to_process[@]}"; do
    if [[ -f "$file_path" ]]; then
        process_file "${file_path#./}"
    fi
done

cat << EOF
--------------------------------------
Операция завершена.
Обработано файлов:         $files_processed
Создано новых директорий: $dirs_created
Ошибок:                    $errors_count
--------------------------------------
EOF
