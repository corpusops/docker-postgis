#!/usr/bin/env bash
set -ex
if ( grep -q ACCEPT_USE_OF_DEPRECATED_PROJ_API_H $@);then exit 0;fi
sed -i -r \
    -e "s/AC_CHECK_HEADER..proj_api.h.*/AC_CHECK_HEADER([proj_api.h], [], [AC_MSG_ERROR([could not find proj_api.h - you may need to specify the directory of a PROJ.4 installation using --with-projdir])],[\\n#define ACCEPT_USE_OF_DEPRECATED_PROJ_API_H 1\\n])\\n\\n/g" $@
sed -i -r \
    -e 's/PROJ_CPPFLAGS="-I\$PROJDIR\/include"/PROJ_CPPFLAGS="-I$PROJDIR\/include -DACCEPT_USE_OF_DEPRECATED_PROJ_API_H=1"/g' \
    $@
# vim:set et sts=4 ts=4 tw=0:
