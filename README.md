# Docker postgis images
- This repository provides tags for the following docker images:
    - [corpusops/postgis-bare](https://hub.docker.com/r/corpusops/postgis-bare)
- The additional tags from [corpusops/docker-images](https://github.com/corpusops/docker-images) are based on those images:
    - [corpusops/postgis](https://hub.docker.com/r/corpusops/postgis)


- Those images are based on
    [postgres](https://github.com/docker-library/postgres) and
    [mdillon/postgis](https://github.com/md5/docker-postgis) and

- And the reason for those to exist is to explicitly tag version tags and avoid non wanted production upgrades.

## Credits & documentation on image usage
- [And For **POSTGIS** based / inspired from this image](https://github.com/appropriate/docker-postgis)

## Supported tags
### postgis
- The following `corpusops/postgis-bare:<tag>[-alpine]` Docker Image tags are supported. <br/>
  The form is ``corpusops/postgis-bare:<POSTGIS_VER>-<POSTGIS_VER>``
    - `-alpine` suffix variant is supported for most versions except ``9.0`` & ``9.1``, <br>
      Please refer to [online tags](https://hub.docker.com/r/corpusops/postgis-bare/tags).
        - eg: ``corpusops/postgis-bare:9.5-2.4-alpine``
    - 9 (copy of latest 9 tag)
        - 9.0-2.1
        - 9.1-2.2
        - 9.2-2.2
        - 9.2-2.2
        - 9.2-2.3
        - 9.3-2.3
        - 9.3-2.4
        - 9.4-2.3
        - 9.4-2.4
        - 9.4-2.5
        - 9.5-2.4
        - 9.5-2.5
        - 9.6-2.4
        - 9.6-2.5
        - 9.0 (copy of latest 9.1-2.1 tag)
        - 9.1 (copy of latest 9.1-2.2 tag)
        - 9.2 (copy of latest 9.2-2.3 tag)
        - 9.3 (copy of latest 9.3-2.4 tag)
        - 9.4 (copy of latest 9.5-2.5 tag)
        - 9.5 (copy of latest 9.4-2.5 tag)
        - 9.6 (copy of latest 9.6-2.5 tag)
    - 10 (copy of latest 10 tag)
        - 10-2.4
        - 10-2.5
    - 11 (copy of latest 11 tag)
        - 11-2.5
    - latest: (copy of latest 11 tag)
    - alpine: (copy of latest 11 alpine tag)

## Support development
- [paypal](https://paypal.me/kiorky)
