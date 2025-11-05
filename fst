#!/usr/bin/env bash

# ===================================================================================
#                                  СТРОГИЙ РЕЖИМ
# ===================================================================================
# set -e: немедленно выйти, если команда завершается с ошибкой.
# set -u: выйти при использовании необъявленной переменной.
# set -o pipefail: вернуть ненулевой статус, если любая команда в конвейере (pipe)
#                  завершается с ошибкой.
set -euo pipefail

# ===================================================================================
#                               СЕКЦИЯ: Конфигурация
# ===================================================================================
# В этом блоке содержатся все настраиваемые параметры скрипта.

# --- Основные названия директорий ---
readonly DIR_BASE="Sorted"
readonly DIR_IMAGES="$DIR_BASE/Images"
readonly DIR_VIDEOS="$DIR_BASE/Videos"
readonly DIR_MUSIC="$DIR_BASE/Music"
readonly DIR_DOCUMENTS="$DIR_BASE/Documents"
readonly DIR_DOCUMENTS_TEXT="$DIR_DOCUMENTS/Texts"
readonly DIR_DOCUMENTS_TABLES="$DIR_DOCUMENTS/Tables"
readonly DIR_EXECUTABLES="$DIR_BASE/Executables"
readonly DIR_PACKAGES="$DIR_BASE/Packages"
readonly DIR_TORRENTS="$DIR_BASE/Torrents"
readonly DIR_PYTHON="$DIR_BASE/Python"
readonly DIR_ARCHIVES="$DIR_BASE/Archives"
readonly DIR_BLENDER="$DIR_BASE/Blend"
readonly DIR_OTHER="$DIR_BASE/Other"

# --- Карта категорий и соответствующих им расширений файлов ---
# Ключ - целевая директория, значение - строка с расширениями через пробел.
declare -rA CATEGORY_TO_EXTENSIONS=(
    ["$DIR_IMAGES"]="jpg jpeg png gif bmp svg psd kra tiff heic webp"
    ["$DIR_VIDEOS"]="mp4 avi mkv mov webm flv mpg wmv"
    ["$DIR_MUSIC"]="mp3 wav ogg flac aac m4a wma mid flp"
    ["$DIR_DOCUMENTS_TEXT"]="pdf odf txt md doc docx rtf epub"
    ["$DIR_DOCUMENTS_TABLES"]="xls xlsx csv ods xlsm"
    ["$DIR_EXECUTABLES"]="exe bin sh jar dll bat app"
    ["$DIR_PACKAGES"]="rpm deb flatpak appimage apk snap"
    ["$DIR_TORRENTS"]="torrent"
    ["$DIR_PYTHON"]="py pyc pyo"
    ["$DIR_ARCHIVES"]="zip rar tar gz 7z bz2 xz"
    ["$DIR_BLENDER"]="blend"
)

# ===================================================================================
#                             СЕКЦИЯ: Глобальные переменные
# ===================================================================================
# Эти переменные изменяются в ходе выполнения скрипта.

# --- Флаги состояния ---
is_recursive=0
is_date_sort=0
is_copy_mode=0
is_quiet=0
skip_prompt=0
is_global_mode=0

# --- Параметры ---
output_dir=""
exclusions=()

# --- Статистика ---
files_processed=0
dirs_created=0
errors_count=0

# --- Информация о действии ---
action_name="Перемещение"
action_past_tense="Перемещено"

# --- Метаданные скрипта ---
script_path=""

# ===================================================================================
#                                 СЕКЦИЯ: Функции
# ===================================================================================

# -----------------------------------------------------------------------------------
# Функция: show_help
# Назначение: Отображает справочное сообщение и завершает работу скрипта.
# -----------------------------------------------------------------------------------
show_help() {
  cat << EOF
Универсальный скрипт для сортировки файлов.

Использование: $(basename "$0") [flags]

По умолчанию сортирует файлы из текущей директории в её же подпапки.

Флаги:
-o, --output DIR  Сортировать файлы в указанную директорию DIR.
-g, --global      Сортировать файлы в стандартные папки пользователя (~/Pictures, ~/Videos и т.д.).
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

# -----------------------------------------------------------------------------------
# Функция: log_info
# Назначение: Выводит информационное сообщение, если не включен тихий режим.
# Аргументы:
#   $@ - Текст сообщения.
# -----------------------------------------------------------------------------------
log_info() {
    if [[ "$is_quiet" -eq 0 ]]; then
        echo "$@"
    fi
}

# -----------------------------------------------------------------------------------
# Функция: log_error
# Назначение: Выводит сообщение об ошибке в stderr.
# Аргументы:
#   $@ - Текст сообщения.
# -----------------------------------------------------------------------------------
log_error() {
    echo "ОШИБКА: $@" >&2
}

# -----------------------------------------------------------------------------------
# Функция: generate_ext_to_category_map
# Назначение: Создает ассоциативный массив для быстрого поиска категории по расширению.
# Результат: Глобальный массив `ext_to_category_map` становится доступным для чтения.
# -----------------------------------------------------------------------------------
generate_ext_to_category_map() {
    declare -gA ext_to_category_map # -g делает массив глобальным
    for category in "${!CATEGORY_TO_EXTENSIONS[@]}"; do
        # Читаем строку расширений в массив
        read -r -a extensions_array <<< "${CATEGORY_TO_EXTENSIONS[$category]}"
        for ext in "${extensions_array[@]}"; do
            ext_to_category_map["$ext"]="$category"
        done
    done
}

# -----------------------------------------------------------------------------------
# Функция: setup_target_directories
# Назначение: Инициализирует ассоциативный массив с путями к целевым директориям.
# Аргументы:
#   $1 - Базовая директория для сортировки.
# Результат: Глобальный массив `category_dirs` заполняется путями.
# -----------------------------------------------------------------------------------
setup_target_directories() {
    local base_dest_dir="$1"
    declare -gA category_dirs # -g делает массив глобальным

    if [[ "$is_global_mode" -eq 1 ]]; then
        # Используем стандартные директории пользователя XDG
        local base_docs; base_docs="$(xdg-user-dir DOCUMENTS 2>/dev/null || echo "$base_dest_dir/Documents")"
        category_dirs=(
            ["$DIR_IMAGES"]="$(xdg-user-dir PICTURES 2>/dev/null || echo "$base_dest_dir/$DIR_IMAGES")"
            ["$DIR_VIDEOS"]="$(xdg-user-dir VIDEOS 2>/dev/null || echo "$base_dest_dir/$DIR_VIDEOS")"
            ["$DIR_MUSIC"]="$(xdg-user-dir MUSIC 2>/dev/null || echo "$base_dest_dir/$DIR_MUSIC")"
            ["$DIR_DOCUMENTS_TEXT"]="$base_docs"
            ["$DIR_DOCUMENTS_TABLES"]="$base_docs"
        )
    else
        # Используем поддиректории в базовой директории
        local base_docs="$base_dest_dir/$DIR_DOCUMENTS"
        category_dirs=(
            ["$DIR_IMAGES"]="$base_dest_dir/$DIR_IMAGES"
            ["$DIR_VIDEOS"]="$base_dest_dir/$DIR_VIDEOS"
            ["$DIR_MUSIC"]="$base_dest_dir/$DIR_MUSIC"
            ["$DIR_DOCUMENTS_TEXT"]="$base_docs/$DIR_DOCUMENTS_TEXT"
            ["$DIR_DOCUMENTS_TABLES"]="$base_docs/$DIR_DOCUMENTS_TABLES"
        )
    fi

    # Добавляем остальные категории, которые всегда создаются локально
    category_dirs["$DIR_EXECUTABLES"]="$base_dest_dir/$DIR_EXECUTABLES"
    category_dirs["$DIR_PACKAGES"]="$base_dest_dir/$DIR_PACKAGES"
    category_dirs["$DIR_TORRENTS"]="$base_dest_dir/$DIR_TORRENTS"
    category_dirs["$DIR_PYTHON"]="$base_dest_dir/$DIR_PYTHON"
    category_dirs["$DIR_ARCHIVES"]="$base_dest_dir/$DIR_ARCHIVES"
    category_dirs["$DIR_BLENDER"]="$base_dest_dir/$DIR_BLENDER"
    category_dirs["$DIR_OTHER"]="$base_dest_dir/$DIR_OTHER"
}


# -----------------------------------------------------------------------------------
# Функция: process_file
# Назначение: Определяет категорию файла и перемещает/копирует его в нужную директорию.
# Аргументы:
#   $1 - Путь к обрабатываемому файлу.
# -----------------------------------------------------------------------------------
process_file() {
    local file_path="$1"

    # Пропускаем символические ссылки, чтобы избежать рекурсии и ошибок
    if [[ -L "$file_path" ]]; then
        log_info "Пропущен симлинк: $file_path"
        return
    fi

    local filename; filename=$(basename -- "$file_path")
    local extension; extension="${filename##*.}"
    local category

    # Определяем категорию файла
    if [[ "$extension" == "$filename" ]]; then
        # Файл без расширения
        category="$DIR_OTHER"
    else
        extension="${extension,,}" # Приводим расширение к нижнему регистру
        # Ищем категорию в карте, если не найдено - используем DIR_OTHER
        category="${ext_to_category_map[$extension]:-$DIR_OTHER}"
    fi

    # Формируем путь назначения
    local dest_dir="${category_dirs[$category]}"
    if [[ "$is_date_sort" -eq 1 ]]; then
        local date_subdir; date_subdir=$(date -r "$file_path" "+%Y/%m")
        dest_dir="$dest_dir/$date_subdir"
    fi

    # Создаем директорию назначения, если она не существует
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

    # Проверяем, существует ли файл в месте назначения, и генерируем новое имя при необходимости
    local dest_path="$dest_dir/$filename"
    if [[ -e "$dest_path" ]]; then
        local base_name="${filename%.*}"
        local ext_part=""
        if [[ "$filename" == *.* ]]; then
            ext_part=".${filename##*.}"
        fi

        local counter=1
        # Избегаем перезаписи: генерируем уникальное имя файла
        while [[ -e "${dest_dir}/${base_name}_${counter}${ext_part}" ]]; do
            ((++counter))
        done
        dest_path="${dest_dir}/${base_name}_${counter}${ext_part}"
        log_info "Файл '$filename' уже существует, новое имя: '$(basename "$dest_path")'"
    fi

    # Выполняем копирование или перемещение
    local cmd_to_run=mv
    if [[ "$is_copy_mode" -eq 1 ]]; then
        cmd_to_run=cp
    fi

    if "$cmd_to_run" -n "$file_path" "$dest_path"; then # -n предотвращает перезапись
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

# --- Предварительные проверки ---
# Защита от случайного запуска в корневой директории
if [[ "$(pwd)" == "/" ]]; then
    log_error "Запуск из корневой директории (/) запрещен в целях безопасности."
    exit 1
fi
script_path=$(realpath "$0")

# --- Парсинг аргументов командной строки ---
while getopts ":o:grdca:qyh" opt; do
    case $opt in
        o) output_dir="$OPTARG" ;;
        g) is_global_mode=1 ;;
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

# --- Инициализация ---
# Создаем карту "расширение -> категория" для быстрого поиска
generate_ext_to_category_map

# Определяем базовую директорию назначения
base_dest_dir="."
dest_type_description="Локальная сортировка в '$(pwd)'"
if [[ -n "$output_dir" ]]; then
    base_dest_dir="$output_dir"
    dest_type_description="Сортировка в указанную директорию '$output_dir'"
elif [[ "$is_global_mode" -eq 1 ]]; then
    base_dest_dir="$HOME"
    dest_type_description="Глобальная сортировка в домашние папки пользователя"
fi

# Настраиваем полные пути для всех целевых директорий
setup_target_directories "$base_dest_dir"

# --- Поиск файлов для обработки ---
log_info "Анализ файлов для сортировки..."
find_args=(".")
if [[ "$is_recursive" -eq 0 ]]; then
    find_args+=("-maxdepth" "1")
fi
find_args+=("-type" "f")

# Исключаем сам скрипт из обработки
find_args+=("-not" "-path" "./$(basename "$script_path")")

# Добавляем пользовательские исключения
for pattern in "${exclusions[@]}"; do
    find_args+=("-not" "-path" "./$pattern")
done

# `mapfile` читает вывод `find` в массив `files_to_process`
# Использование -print0 и -d '' безопасно для имен файлов с пробелами и спецсимволами
mapfile -t -d '' files_to_process < <(find "${find_args[@]}" -print0)
file_count=${#files_to_process[@]}

if [[ "$file_count" -eq 0 ]]; then
    log_info "Не найдено файлов для обработки."
    exit 0
fi

# --- Сводка и подтверждение ---
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

# --- Основной цикл обработки ---
for file_path in "${files_to_process[@]}"; do
    # Убедимся, что это действительно файл (find должен это гарантировать, но это доп. проверка)
    if [[ -f "$file_path" ]]; then
        # Удаляем префикс './' для более чистого вывода
        process_file "${file_path#./}"
    fi
done

# --- Финальный отчет ---
cat << EOF
--------------------------------------
Операция завершена.
Обработано файлов:         $files_processed
Создано новых директорий: $dirs_created
Ошибок:                    $errors_count
--------------------------------------
EOF
