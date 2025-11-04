#!/usr/bin/env bash

# Используем строгий режим
# set -e: выход при ошибке
# set -u: выход при использовании необъявленной переменной
# set -o pipefail: выход, если команда в пайпе завершается с ошибкой
set -euo pipefail

# --- КОНФИГУРАЦИЯ И КОНСТАНТЫ ---

# Названия директорий для категорий
readonly DIR_IMAGES="Images"
readonly DIR_VIDEOS="Videos"
readonly DIR_MUSIC="Music"
readonly DIR_DOCUMENTS="Documents"
readonly DIR_DOCUMENTS_TEXT="Texts"
readonly DIR_DOCUMENTS_TABLES="Tables"
readonly DIR_EXECUTABLES="Executables"
readonly DIR_PACKAGES="Packages"
readonly DIR_TORRENTS="Torrents"
readonly DIR_PYTHON="Python"
readonly DIR_ARCHIVES="Archives"
readonly DIR_BLENDER="Blend"
readonly DIR_OTHER="Other"

# Ассоциативный массив "категория -> расширения" (удобный для редактирования)
declare -rA CATEGORY_TO_EXTS=(
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

# --- ГЕНЕРАЦИЯ БЫСТРОЙ ТАБЛИЦЫ ПОИСКА (не редактировать) ---
declare -A EXT_TO_CAT
for category in "${!CATEGORY_TO_EXTS[@]}"; do
  read -r -a extensions_array <<< "${CATEGORY_TO_EXTS[$category]}"
  for ext in "${extensions_array[@]}"; do
    EXT_TO_CAT["$ext"]="$category"
  done
done
declare -rA EXT_TO_CAT

# --- ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ ---
RECURSIVE=0; DATE_SORT=0; COPY_MODE=0; QUIET=0; VERBOSE=0; GLOBAL_MODE=0
OUTPUT_DIR=""; EXCLUSIONS=()
FILES_PROCESSED=0; DIRS_CREATED=0; ERRORS_COUNT=0
ACTION_NAME="Перемещение"; ACTION_PAST_TENSE="Перемещено"
SCRIPT_PATH=""

# --- ФУНКЦИИ ---
show_help() {
  cat << EOF
Универсальный скрипт для сортировки файлов.

Использование: $(basename "$0") [flags]

По умолчанию сортирует файлы из текущей директории в подпапки этой же директории.

Флаги:
  -o, --output DIR  Сортировать файлы в указанную директорию DIR.
  -g, --global      Сортировать файлы в стандартные папки пользователя (~/Pictures, ~/Videos и т.д.).
  -r, --recursive   Включить рекурсивный поиск файлов в поддиректориях.
  -d, --date        Сортировать файлы по дате (создавать папки ГГГГ/ММ).
  -c, --copy        Копировать файлы вместо перемещения.
  -a, --avoid PAT   Исключить файлы или директории, соответствующие шаблону (например, -a "*.tmp" или -a "MyFolder/*"). Можно использовать несколько раз.
  -q, --quiet       Тихий режим (показывать только ошибки и итоговую сводку).
  -v, --verbose     Подробный режим (показывать дополнительную информацию).
  -h, --help        Показать это справочное сообщение.
EOF
  exit 0
}

log_info() { if [[ "$QUIET" -eq 0 ]]; then echo "$@"; fi; }
log_verbose() { if [[ "$VERBOSE" -eq 1 ]]; then echo "VERBOSE: $@"; fi; }
log_error() { echo "ОШИБКА: $@" >&2; }
cleanup() { :; }
trap cleanup EXIT INT TERM

process_file() {
  local file_path="$1"

  if [[ -L "$file_path" ]]; then log_verbose "Пропущен симлинк: $file_path"; return; fi
  if [[ "$(realpath "$file_path")" == "$SCRIPT_PATH" ]]; then return; fi

  local filename; filename=$(basename -- "$file_path")
  local extension; extension="${filename##*.}"
  local category

  if [[ "$extension" == "$filename" ]]; then
    category="$DIR_OTHER"
  else
    extension="${extension,,}"
    category="${EXT_TO_CAT[$extension]:-$DIR_OTHER}"
  fi

  local dest_dir="${DIRS[$category]}"
  if [ "$DATE_SORT" -eq 1 ]; then
    local date_subdir; date_subdir=$(date -r "$file_path" "+%Y/%m")
    dest_dir="$dest_dir/$date_subdir"
  fi

  if [[ ! -d "$dest_dir" ]]; then
      if mkdir -p "$dest_dir"; then
        ((++DIRS_CREATED)); log_verbose "Создана директория: $dest_dir"
      else
        log_error "Не удалось создать директорию: $dest_dir"; ((++ERRORS_COUNT)); return
      fi
  fi

  local dest_path="$dest_dir/$filename"
  if [ -e "$dest_path" ]; then
    local base_name="${filename%.*}"; local counter=1
    local ext_part=""; if [[ "$filename" == *.* ]]; then ext_part=".${filename##*.}"; fi
    while [ -e "${dest_dir}/${base_name}_${counter}${ext_part}" ]; do ((++counter)); done # ИСПРАВЛЕНО
    dest_path="${dest_dir}/${base_name}_${counter}${ext_part}"
    log_verbose "Файл '$filename' существует, новое имя: '$(basename "$dest_path")'"
  fi

  local cmd_to_run=mv
  if [ "$COPY_MODE" -eq 1 ]; then cmd_to_run=cp; fi

  if "$cmd_to_run" -n "$file_path" "$dest_path"; then
    log_info "${ACTION_PAST_TENSE}: $file_path -> $dest_path"; ((++FILES_PROCESSED)) # ИСПРАВЛЕНО
  else
    log_error "Не удалось обработать $file_path"; ((++ERRORS_COUNT)) # ИСПРАВЛЕНО
  fi
}

# --- ТОЧКА ВХОДА ---
if [[ "$(pwd)" == "/" ]]; then log_error "Запуск из / запрещен."; exit 1; fi
SCRIPT_PATH=$(realpath "$0")

while getopts ":o:grdca:qvh" opt; do
  case $opt in
    o) OUTPUT_DIR="$OPTARG";; g) GLOBAL_MODE=1;; r) RECURSIVE=1;; d) DATE_SORT=1;;
    c) COPY_MODE=1; ACTION_NAME="Копирование"; ACTION_PAST_TENSE="Скопировано";;
    a) EXCLUSIONS+=("$OPTARG");; q) QUIET=1;; v) VERBOSE=1;; h) show_help;;
    \?) log_error "Неверный флаг: -$OPTARG"; exit 1;;
    :) log_error "Флаг -$OPTARG требует аргумент."; exit 1;;
  esac
done

BASE_DEST_DIR="."; DEST_TYPE="Локальная сортировка в '$(pwd)'"
if [[ -n "$OUTPUT_DIR" ]]; then
  BASE_DEST_DIR="$OUTPUT_DIR"; DEST_TYPE="Сортировка в указанную директорию '$OUTPUT_DIR'"
elif [[ "$GLOBAL_MODE" -eq 1 ]]; then
  BASE_DEST_DIR="$HOME"; DEST_TYPE="Глобальная сортировка в домашние папки пользователя"
fi

declare -A DIRS
if [[ "$GLOBAL_MODE" -eq 1 ]]; then
  BASE_DOCS="$(xdg-user-dir DOCUMENTS 2>/dev/null || echo "$BASE_DEST_DIR/$DIR_DOCUMENTS")"
  DIRS=( ["$DIR_IMAGES"]="$(xdg-user-dir PICTURES 2>/dev/null || echo "$BASE_DEST_DIR/$DIR_IMAGES")" ["$DIR_VIDEOS"]="$(xdg-user-dir VIDEOS 2>/dev/null || echo "$BASE_DEST_DIR/$DIR_VIDEOS")" ["$DIR_MUSIC"]="$(xdg-user-dir MUSIC 2>/dev/null || echo "$BASE_DEST_DIR/$DIR_MUSIC")" ["$DIR_DOCUMENTS_TEXT"]="$BASE_DOCS/$DIR_DOCUMENTS_TEXT" ["$DIR_DOCUMENTS_TABLES"]="$BASE_DOCS/$DIR_DOCUMENTS_TABLES" ["$DIR_EXECUTABLES"]="$BASE_DEST_DIR/$DIR_EXECUTABLES" ["$DIR_PACKAGES"]="$BASE_DEST_DIR/$DIR_PACKAGES" ["$DIR_TORRENTS"]="$BASE_DEST_DIR/$DIR_TORRENTS" ["$DIR_PYTHON"]="$BASE_DEST_DIR/$DIR_PYTHON" ["$DIR_ARCHIVES"]="$BASE_DEST_DIR/$DIR_ARCHIVES" ["$DIR_BLENDER"]="$BASE_DEST_DIR/$DIR_BLENDER" ["$DIR_OTHER"]="$BASE_DEST_DIR/$DIR_OTHER" )
else
  BASE_DOCS="$BASE_DEST_DIR/$DIR_DOCUMENTS"
  DIRS=( ["$DIR_IMAGES"]="$BASE_DEST_DIR/$DIR_IMAGES" ["$DIR_VIDEOS"]="$BASE_DEST_DIR/$DIR_VIDEOS" ["$DIR_MUSIC"]="$BASE_DEST_DIR/$DIR_MUSIC" ["$DIR_DOCUMENTS_TEXT"]="$BASE_DOCS/$DIR_DOCUMENTS_TEXT" ["$DIR_DOCUMENTS_TABLES"]="$BASE_DOCS/$DIR_DOCUMENTS_TABLES" ["$DIR_EXECUTABLES"]="$BASE_DEST_DIR/$DIR_EXECUTABLES" ["$DIR_PACKAGES"]="$BASE_DEST_DIR/$DIR_PACKAGES" ["$DIR_TORRENTS"]="$BASE_DEST_DIR/$DIR_TORRENTS" ["$DIR_PYTHON"]="$BASE_DEST_DIR/$DIR_PYTHON" ["$DIR_ARCHIVES"]="$BASE_DEST_DIR/$DIR_ARCHIVES" ["$DIR_BLENDER"]="$BASE_DEST_DIR/$DIR_BLENDER" ["$DIR_OTHER"]="$BASE_DEST_DIR/$DIR_OTHER" )
fi

log_info "Анализ файлов для сортировки..."
find_args=("."); if [ "$RECURSIVE" -eq 0 ]; then find_args+=("-maxdepth" "1"); fi
find_args+=("-type" "f")
for pattern in "${EXCLUSIONS[@]}"; do find_args+=("-not" "-path" "./$pattern"); done

mapfile -t -d '' files_to_process < <(find "${find_args[@]}" -print0)
file_count=${#files_to_process[@]}
if [ "$file_count" -eq 0 ]; then log_info "Не найдено файлов для обработки."; exit 0; fi

cat << EOF
-------------------------------------
        Сводка операции
-------------------------------------
Действие:         $ACTION_NAME
Источник:         $(pwd)
Назначение:       $DEST_TYPE
Поиск:            $([ "$RECURSIVE" -eq 1 ] && echo "Рекурсивный" || echo "Только в текущей директории")
Сортировка по дате: $([ "$DATE_SORT" -eq 1 ] && echo "Включена (ГГГГ/ММ)" || echo "Выключена")

Найдено для обработки: $file_count файлов.
-------------------------------------
EOF
read -p "Начать? (y/n) " -r REPLY; echo
case "$REPLY" in
  [YyДд]) log_info "Начинаем...";;
  *) echo "Операция отменена."; exit 1;;
esac

for file_path in "${files_to_process[@]}"; do
  if [[ -f "$file_path" ]]; then
    process_file "${file_path#./}"
  fi
done

cat << EOF
-------------------------------------
Операция завершена.
Обработано файлов: $FILES_PROCESSED
Создано новых директорий: $DIRS_CREATED
Ошибок: $ERRORS_COUNT
-------------------------------------
EOF
