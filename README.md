dotfiles
========
The point is to avoid a monolithic .bashrc file.

Based off [Zach Holman's dotfiles](https://github.com/holman/dotfiles). This dotfiles implementation is built for a Bash environment on OSX, works pretty well on Linux (Ubuntu), and hasn't been tested on Cygwin (i hope never!)).

It is modular enough that you can pick and choose what you want.  My main toolset is around

* AWS
* vim
* todo.txt
* Ruby
* Hadoop

Although, this should be in motion, as reflected by the dirs in the repo... which is the whole point, after all :).
# idea
This project manages all of your resource and environment files.  Projects (of your choosing) store their files in directories.  For instance, check out the vim directory.  It contains my .vimrc and .vim directory.

The benefit is, all your environments are under source control and are split into modular deploys.  Adding a new environment is as simple as adding a new directory and putting the appropriate files in there.

Key files

| File | Description|
|---|---|
|\*rc.symlink|Generate .\*rc files in your home directory.  For instance bash_profile.symlink will cause a symlink to be created in ~/.bash_profile -> [dotfiles location]/bash/bash_profile.symlink|
|env.sh|Contain things |
|private_env.sh|Contain things you don't want checked into source control (like passwords or api keys) but which are part of your local environment

# install
Install with **`make install`** (or just `make`).

This symlinks the various `.*rc` files in your home directory to the
respective `*.symlink` files in each topic directory, and creates
`~/.dotfiles` pointing to this repo.

Run **`make uninstall`** to remove all managed symlinks and restore
any backups that were created.

If a file already exists at the target location it will be backed up
to `~/.filename.backup` before being replaced. Re-running `make install`
is safe — existing correct symlinks are skipped.

Run **`make test`** to verify the installer works correctly.

#Assumed installs
* colordiff
* git
* hub
