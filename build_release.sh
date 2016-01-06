#!/bin/sh

# todo:
# - stick to specific git-revision
# - autodownload .definitions

# arguments e.g.:
# "HARDWARE.Linksys WRT54G:GS:GL" standard kernel.addzram kcmdlinetweak patch:901-minstrel-try-all-rates.patch dataretention nopppoe b43minimal olsrsimple nohttps nonetperf
# "HARDWARE.TP-LINK TL-WR1043ND"  standard kernel.addzram kcmdlinetweak patch:901-minstrel-try-all-rates.patch dataretention

log()
{
    logger -s "$( date +"%F %R" ): [$( basename "$(pwd)" )]: $0: $1"
}

[ -z "$1" ] && {
	log "Usage: $0 <buildstring>"
	exit 1
}

[ "$( id -u )" = "0" ] && {
	log "please run as normal user"
	exit 1
}

[ -x "./openwrt-build/mybuild.sh" ] || {
    log "please run the script in the current directory!"
    exit 1
}

resolve_meta() {
    while [ $# -gt 0 ] 
    do
        case "$1" in
            *meta.* )
               read NEW_ARGS < "./openwrt-config/config_${1}.txt"
               ARGS=$(echo "$ARGS" "$NEW_ARGS" | sed "s/$1//g")
               resolve_meta $ARGS
               ;;
            * )
               ;;
       esac
       shift
   done
}

ARGS="$@"
resolve_meta $ARGS
log "[INFO] used options: $ARGS"

TRUNK=trunk

case "$ARGS" in
	*use_trunk*)
		log "[INFO] we will be on top of openwrt development"
		TRUNK=trunk
	;;
	*use_bb1407*)
		log "[INFO] we will use the 14.07 barrier breaker stable version"
		TRUNK=bb1407
	;;
	*use_cc1505*)
		log "[INFO] we will use the 15.05 chaos calmer stable version"
		TRUNK=cc1505
	;;
esac


changedir()
{
	[ -d "$1" ] || {
		log "creating dir $1"
		mkdir -p "$1" 
	}

	log "going into $1"
	cd "$1"
}

clone()
{
	local repo="$1"
	local dir="$( basename "$repo" | cut -d'.' -f1 )"

	if [ -d "$dir" ]; then
        read OPENWRT_RELEASE < "$dir/.openwrt_version"
        [ "$OPENWRT_RELEASE" = "$TRUNK" ] || {
            log "Error: OpenWRT version mismatch: $OPENWRT_RELEASE already cloned but $TRUNK requested" 
            log "Delete folder '$dir' and try again!"
            exit 1
        }
		log "git-cloning of '$repo' already done, just pulling"
		changedir "$dir"
		git stash
		git pull || {
            log "error pulling repo"
            exit 1
        }
		changedir ..
	else
		log "git-cloning from '$repo'"
		git clone --depth=1 "$repo" || { 
           log "error cloning repo" 
           exit 1
       }
       echo "$TRUNK" > "$dir/.openwrt_version"
	fi
	
	if [ -e "../openwrt-config/git_revs" ] && [ $TRUNK = 0 ]; then
		. "../openwrt-config/git_revs"
		case "$repo" in
			*"openwrt"*)
				[ -n "$MY_OPENWRT" ] && {
					changedir "$dir"
					git branch -D "r$MY_OPENWRT"
					git checkout "$( git log -z | tr '\n\0' ' \n' | grep "@$MY_OPENWRT " | cut -d' ' -f2 )" -b r"$MY_OPENWRT" || {
                       log "error during git checkout"
                       exit 1
                    }
					changedir ..
				}
			;;
#			*"packages"*)
#				[ -n "$MY_PACKAGES" ] && {
#					changedir "$dir"
#					git branch -D "r$MY_PACKAGES"
#					git checkout "$( git log -z | tr '\n\0' ' \n' | grep "@$MY_PACKAGES" | cut -d' ' -f2 )" -b r$MY_PACKAGES || {
#                       log "error during git checkout" 
#                       exit 1
#                   }
#					changedir ..
#				}
#			;;
		esac
	fi
}

# print a json file with openwrt and weimarnetz revision, we assume to be in the openwrt directory
print_revisions()
{
	OPENWRT_REV="$( ./scripts/getver.sh )"
	KALUA_REV="$(  grep FFF_PLUS package/base-files/files/etc/variables_fff+ | tr -d '[:space:]'|cut -d '=' -f 2|cut -d '#' -f 1)"	
	echo "{\"OPENWRT_REV\":\"$OPENWRT_REV\",\"KALUA_REV\":\"$KALUA_REV\"}" > "bin/revisions.json"
}

mymake()	# fixme! how to ahve a quiet 'make defconfig'?
{
	log "[START] executing 'make $1 $2 $3'"
	make $1 $2 $3
	log "[READY] executing 'make $1 $2 $3'"
}

prepare_build()		# check possible values via:
{			# ./openwrt-build/mybuild.sh set_build list
	local action

    log "$@"
	for action in "$@"; do {
		log "[START] '$action' from '$*'"

		case "$action" in
			r[0-9]|r[0-9][0-9]|r[0-9][0-9][0-9]|r[0-9][0-9][0-9][0-9]|r[0-9][0-9][0-9][0-9][0-9])
				REV="$( echo "$action" | cut -d'r' -f2 )"
				log "switching to revision r$REV"
				git stash
				git checkout "$( git log -z | tr '\n\0' ' \n' | grep "@$REV " | cut -d' ' -f2 )" -b r"$REV" || {
                log "error while git checkout" 
                exit 1
            }
				continue
			;;
			*use_*)
				continue
			;;
            reset_config)
                ./scripts/feeds clean
                git checkout master 
                git branch -D patched 
                git checkout -b patched master
		esac

		"../openwrt-build/mybuild.sh" set_build "$action" || {
            log "[ERROR] $action failed. aborting"
            exit 1
        }
		log "[READY] '$action' from '$*'"
	} done
}

show_args()
{
	local word

	for word in "$@"; do {
		case "$word" in
			*" "*)
				echo -n " '$word'"
			;;
			*)
				echo -n " $word"
			;;
		esac
	} done
}

#[ -e "/tmp/apply_profile.code.definitions" ] || {
#	log "please make sure, that you have placed you settings in '/tmp/apply_profile.code.definitions'"
#	log "otherwise i'll take the community-settings"
#	sleep 5
#}

# changedir release
if [ "$TRUNK" = "bb1407" ]; then
	clone "git://git.openwrt.org/14.07/openwrt.git" "$TRUNK"
elif [ "$TRUNK" = "cc1505" ]; then
	clone "git://git.openwrt.org/15.05/openwrt.git" "$TRUNK"
else
	clone "git://nbd.name/openwrt.git" "$TRUNK"
fi
changedir openwrt

# clone "$REPOURL"
#copy feeds.conf to openwrt directory
if [ "$TRUNK" = "bb1407" ]; then
	cp "../openwrt-build/feeds.conf.1407" ./feeds.conf
elif [ "$TRUNK" = "cc1505" ]; then
	cp "../openwrt-build/feeds.conf.1505" ./feeds.conf
else
	cp "../openwrt-build/feeds.conf" ./
fi

prepare_build "reset_config" || exit 1
mymake package/symlinks || exit 1
prepare_build $ARGS || exit 1
mymake defconfig || exit 1

for SPECIAL in unoptimized kcmdlinetweak; do {
	case "$ARGS" in
		*"$SPECIAL"*)
			prepare_build $SPECIAL
		;;
	esac
} done

"../openwrt-build/mybuild.sh" make || exit 1 
print_revisions

log "please removing everything via 'rm -fR release' if you are ready"
log "# buildstring: $( show_args "$ARGS" )"
