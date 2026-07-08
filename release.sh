#!/usr/bin/env bash
# 배포 자동화: 버전 올리기 → 커밋 → 태그 → push → GitHub Actions가 APK 빌드/릴리스.
#
# 사용법:
#   ./release.sh            # patch 올림 (0.2.0 → 0.2.1)
#   ./release.sh minor      # minor 올림 (0.2.0 → 0.3.0)
#   ./release.sh major      # major 올림 (0.2.0 → 1.0.0)
#   ./release.sh 0.5.2      # 특정 버전으로 지정
#
#   커밋 메시지 지정 (변경사항을 release 커밋과 분리해서 남김):
#   ./release.sh -m "웹뷰 길찾기 수정"
#   ./release.sh minor -m "기능 추가"
set -e
cd "$(dirname "$0")"

# 커밋 메시지(-m) 옵션 파싱. 나머지는 버전 인자로 남긴다.
msg=""
args=()
while [ $# -gt 0 ]; do
  case "$1" in
    -m|--message) msg="$2"; shift 2 ;;
    *) args+=("$1"); shift ;;
  esac
done
set -- "${args[@]}"

# 1) 현재 버전 읽기 (pubspec.yaml 의 "version: X.Y.Z" 또는 "X.Y.Z+build")
cur=$(grep -E '^version:' pubspec.yaml | sed -E 's/version:[[:space:]]*//; s/\+.*//')
IFS='.' read -r MA MI PA <<< "$cur"

arg="${1:-patch}"
case "$arg" in
  major) MA=$((MA+1)); MI=0; PA=0 ;;
  minor) MI=$((MI+1)); PA=0 ;;
  patch) PA=$((PA+1)) ;;
  *.*.*) MA=$(echo "$arg"|cut -d. -f1); MI=$(echo "$arg"|cut -d. -f2); PA=$(echo "$arg"|cut -d. -f3) ;;
  *) echo "사용법: ./release.sh [patch|minor|major|X.Y.Z]"; exit 1 ;;
esac
new="$MA.$MI.$PA"

echo ">> 버전: $cur → $new"

# 2) 기존 변경사항을 먼저 별도 커밋으로 남긴다 (버전 범프와 분리).
#    -m 을 주면 그 메시지로, 안 주면 대화형으로 입력받는다.
if [ -n "$(git status --porcelain)" ]; then
  if [ -z "$msg" ]; then
    printf ">> 변경사항이 있습니다. 커밋 메시지를 입력하세요: "
    read -r msg
  fi
  if [ -z "$msg" ]; then
    echo ">> 커밋 메시지가 비어 있습니다. 중단합니다."; exit 1
  fi
  git add -A
  git commit -m "$msg"
  echo ">> 변경사항 커밋 완료: $msg"
fi

# 3) pubspec 버전 갱신 (versionCode 는 build 번호로 자동 증가)
#    "version: X.Y.Z+N" 형태를 유지하기 위해 build 번호도 올린다.
build=$(grep -E '^version:' pubspec.yaml | sed -E 's/.*\+//; t; s/.*//')
build=$(( ${build:-0} + 1 ))
sed -i -E "s/^version:.*/version: $new+$build/" pubspec.yaml
echo ">> pubspec.yaml → version: $new+$build"

# 4) 버전 범프 커밋 + 태그 + push
git add -A
git commit -m "release: v$new" || echo ">> 커밋할 변경 없음(버전만 태그)"
git tag "v$new"
git push origin HEAD
git push origin "v$new"

echo ""
echo "✅ v$new 배포 시작됨. GitHub Actions 탭에서 빌드 진행을 확인하세요."
echo "   빌드 완료되면 폰에서 앱 실행 시 업데이트 알림이 뜹니다."
