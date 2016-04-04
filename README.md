# Diriterator
Runs a script for each file in a directory hierarchy using GNU parallel.
This is useful when converting a lot of media files.

## Instructions
The script requires GNU parallel to be installed.

Let's assume you have a directory tree like this

```
music_lib_mp3
    Artist 1
        Album 1
            Song 1.mp3
            Song 2.mp3
            ...
        Album 2
            Song 1.mp3
            Song 2.mp3
        ...
    ...
```

and want to convert all files to AAC in parallel and the converted
files should be placed in a similar directory tree:

```
music_lib_aac
    Artist 1
        Album 1
            Song 1.m4a
            Song 2.m4a
            ...
        Album 2
            Song 1.m4a
            Song 2.m4a
        ...
    ...
```

Just run:
```
diriterator --base-dir "./music_lib_aac" --target-dir "./music_lib_aac" --filter ".*\.(mp3$)" --cmd "mkdir -p \"\$ITERATOR_TARGET_DIR\" && ffmpeg -i \"\$ITERATOR_FULL_PATH\" -c:a libfdk_aac -vbr 4 \"\$ITERATOR_TARGET_DIR/\$ITERATOR_FILE_NAME_WITHOUT_EXTENSION.m4a"
```

The repository PKGBUILDs (also on my GitHub page) contains files for building an Arch Linux package.
