#!/usr/bin/env bash

# Используем строгий режим для большей надежности
set -uo pipefail

# Названия директорий

DIR_IMAGES="Images"
DIR_VIDEOS="Videos"
DIR_MUSIC="Music"
DIR_DOCUMENTS="Documents"
DIR_DOCUMENTS_TEXT="Texts"
DIR_DOCUMENTS_TABLES="Tables"
DIR_EXECUTABLES="Executables"
DIR_PACKAGES="Packages"
DIR_TORRENTS="Torrents"
DIR_PYTHON="Python"
DIR_ARCHIVES="Archives"
DIR_BLENDER="Blend"
DIR_OTHER="Other"

# Функция для вывода справки
show_help() {
  # basename "$0" покажет имя, под которым был запущен скрипт
  cat << EOF
Универсальный скрипт для сортировки файлов.

Использование: $(basename "$0") [flags]

Флаги:
  -l, --local      Сортировать в подпапки текущей директории.
  -r, --recursive  Включить рекурсивный поиск файлов.
  -d, --date       Сортировать файлы по дате (создавать папки ГГГГ/ММ).
  -c, --copy       Копировать файлы вместо перемещения.
  -q, --quiet      Тихий режим (показывать только ошибки и итоговую сводку).
  -v, --verbose    Подробный режим (показывать дополнительную информацию).
  -h, --help       Показать это справочное сообщение.
EOF
  exit 0
}

# Переменные для флагов и счетчиков
LOCAL_MODE=0
RECURSIVE=0
DATE_SORT=0
COPY_MODE=0
QUIET=0
VERBOSE=0

FILES_PROCESSED=0
DIRS_CREATED=0
ERRORS_COUNT=0
ACTION_NAME="Перемещение"
ACTION_PAST_TENSE="Перемещено"

# Обработка флагов командной строки
# Используем цикл while для обработки комбинаций типа -lrc
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) show_help;;
        -l|--local) LOCAL_MODE=1; shift;;
        -r|--recursive) RECURSIVE=1; shift;;
        -d|--date) DATE_SORT=1; shift;;
        -c|--copy) COPY_MODE=1; ACTION_NAME="Копирование"; ACTION_PAST_TENSE="Скопировано"; shift;;
        -q|--quiet) QUIET=1; shift;;
        -v|--verbose) VERBOSE=1; shift;;
        *) break;; # Прекращаем разбор флагов, если встретили что-то другое
    esac
done

# Функции для логирования
log_info() {
    if [[ "$QUIET" -eq 0 ]]; then echo "$@"; fi
}
log_verbose() {
    if [[ "$VERBOSE" -eq 1 ]]; then echo "VERBOSE: $@"; fi
}
log_error() {
    # Ошибки выводим всегда в stderr
    echo "ОШИБКА: $@" >&2
}

# Определение категорий и расширений
declare -A EXT_TO_CAT
for ext in jpg jpeg png gif bmp svg psd kra tiff heic webp; do EXT_TO_CAT[$ext]="$DIR_IMAGES"; done
for ext in mp4 avi mkv mov webm flv mpg wmv; do EXT_TO_CAT[$ext]="$DIR_VIDEOS"; done
for ext in mp3 wav ogg flac aac m4a wma mid flp; do EXT_TO_CAT[$ext]="$DIR_MUSIC"; done
for ext in pdf odf txt md doc docx rtf epub; do EXT_TO_CAT[$ext]="$DIR_DOCUMENTS_TEXT"; done
for ext in xls xlsx csv ods xlsm; do EXT_TO_CAT[$ext]="$DIR_DOCUMENTS_TABLES"; done
for ext in exe bin sh jar dll bat app; do EXT_TO_CAT[$ext]="$DIR_EXECUTABLES"; done
for ext in rpm deb flatpak appimage apk snap; do EXT_TO_CAT[$ext]="$DIR_PACKAGES"; done
for ext in torrent; do EXT_TO_CAT[$ext]="$DIR_TORRENTS"; done
for ext in py pyc pyo; do EXT_TO_CAT[$ext]="$DIR_PYTHON"; done
for ext in zip rar tar gz 7z bz2 xz; do EXT_TO_CAT[$ext]="$DIR_ARCHIVES"; done
for ext in blend; do EXT_TO_CAT[$ext]="$DIR_BLENDER"; done

# Определение целевых директорий
declare -A DIRS
if [ "$LOCAL_MODE" -eq 1 ]; then
  BASE_DOCS="./$DIR_DOCUMENTS"
  DIRS=( ["$DIR_IMAGES"]="./$DIR_IMAGES" ["$DIR_VIDEOS"]="./$DIR_VIDEOS" ["$DIR_MUSIC"]="./$DIR_MUSIC" ["$DIR_DOCUMENTS_TEXT"]="$BASE_DOCS/$DIR_DOCUMENTS_TEXT" ["$DIR_DOCUMENTS_TABLES"]="$BASE_DOCS/$DIR_DOCUMENTS_TABLES" ["$DIR_EXECUTABLES"]="./$DIR_EXECUTABLES" ["$DIR_PACKAGES"]="./$DIR_PACKAGES" ["$DIR_TORRENTS"]="./$DIR_TORRENTS" ["$DIR_PYTHON"]="./$DIR_PYTHON" ["$DIR_ARCHIVES"]="./$DIR_ARCHIVES" ["$DIR_BLENDER"]="./$DIR_BLENDER" ["$DIR_OTHER"]="./$DIR_OTHER" )
else
  BASE_DOCS="$(xdg-user-dir DOCUMENTS 2>/dev/null || echo "$HOME/$DIR_DOCUMENTS")"
  DIRS=( ["$DIR_IMAGES"]="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/$DIR_IMAGES")" ["$DIR_VIDEOS"]="$(xdg-user-dir VIDEOS 2>/dev/null || echo "$HOME/$DIR_VIDEOS")" ["$DIR_MUSIC"]="$(xdg-user-dir MUSIC 2>/dev/null || echo "$HOME/$DIR_MUSIC")" ["$DIR_DOCUMENTS_TEXT"]="$BASE_DOCS/$DIR_DOCUMENTS_TEXT" ["$DIR_DOCUMENTS_TABLES"]="$BASE_DOCS/$DIR_DOCUMENTS_TABLES" ["$DIR_EXECUTABLES"]="$HOME/$DIR_EXECUTABLES" ["$DIR_PACKAGES"]="$HOME/$DIR_PACKAGES" ["$DIR_TORRENTS"]="$HOME/$DIR_TORRENTS" ["$DIR_PYTHON"]="$HOME/$DIR_PYTHON" ["$DIR_ARCHIVES"]="$HOME/$DIR_ARCHIVES" ["$DIR_BLENDER"]="$HOME/$DIR_BLENDER" ["$DIR_OTHER"]="$HOME/$DIR_OTHER" )
fi

# Подтверждение от пользователя
log_info "Действие: $ACTION_NAME"
log_info "Целевая директория: $(pwd)"
if [ "$RECURSIVE" -eq 1 ]; then log_info "Режим: рекурсивный"; fi
if [ "$DATE_SORT" -eq 1 ]; then log_info "Режим: сортировка по дате (ГГГГ/ММ)"; fi

# Запрос подверждения
read -p "Начать? (y/n) " REPLY
case "$REPLY" in
  [YyДд])
    log_info "Начинаем..."
    ;;
  *)
    echo "Операция отменена."
    exit 1
    ;;
esac

# Основная функция обработки файла
process_file() {
  local file_path="$1"
  if [ "$(realpath "$file_path")" == "$(realpath "$0")" ]; then return; fi

  local filename; filename=$(basename -- "$file_path")
  local extension; extension="${filename##*.}"
  local category

  if [[ "$extension" == "$filename" ]]; then
    category="$DIR_OTHER"
  else
    extension="${extension,,}"
    category="${EXT_TO_CAT[$extension]:-$DIR_OTHER}" # Используем значение по умолчанию, если ключ не найден
  fi

  local dest_dir="${DIRS[$category]}"

  # Добавляем подпапки с датой, если включен флаг -d
  if [ "$DATE_SORT" -eq 1 ]; then
    local date_subdir; date_subdir=$(date -r "$file_path" "+%Y/%m")
    dest_dir="$dest_dir/$date_subdir"
  fi

  # Создаем целевую директорию, если она не существует
  if [[ ! -d "$dest_dir" ]]; then
      mkdir -p "$dest_dir" && ((DIRS_CREATED++))
      log_verbose "Создана директория: $dest_dir"
  fi

  local dest_path="$dest_dir/$filename"

  # Обработка дубликатов
  if [ -e "$dest_path" ]; then
    local base_name="${filename%.*}"
    local counter=0
    local ext_part=""; if [[ "$filename" == *.* ]]; then ext_part=".${filename##*.}"; fi

    while [ -e "${dest_dir}/${base_name}_${counter}${ext_part}" ]; do
      ((counter++))
    done
    dest_path="${dest_dir}/${base_name}_${counter}${ext_part}"
  fi

  # Выполнение действия (копирование или перемещение)
  local operation_success=0
  if [ "$COPY_MODE" -eq 1 ]; then
    cp -n "$file_path" "$dest_path" && operation_success=1
  else
    mv -n "$file_path" "$dest_path" && operation_success=1
  fi

  # Обновление счетчиков и логирование
  if [ "$operation_success" -eq 1 ]; then
    log_info "${ACTION_PAST_TENSE}: $file_path -> $dest_path"
    ((FILES_PROCESSED++))
  else
    log_error "Не удалось обработать $file_path"
    ((ERRORS_COUNT++))
  fi
}

# Логика сортировки (основной цикл)
if [ "$RECURSIVE" -eq 1 ]; then
  while IFS= read -r file; do
    if [ "$file" != "." ]; then process_file "$file"; fi
  done < <(find . -type f -not -path '*/\.*')
else
  for file in *; do
    if [ -f "$file" ]; then process_file "$file"; fi
  done
fi

# Итоговая сводка
echo "-------------------------------------"
echo "Операция завершена."
echo "Обработано файлов: $FILES_PROCESSED"
echo "Создано новых директорий: $DIRS_CREATED"
echo "Ошибок: $ERRORS_COUNT"
echo "-------------------------------------"
