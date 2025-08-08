#!/bin/bash

function backupconfigs() {
    cp -rf $HOME/.config/dotfiler/ .config/dotfiler/
}
backupconfigs
