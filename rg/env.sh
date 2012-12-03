#export PS1="\h.\#[\w] "
#PATH=.:/Applications/MacVim.app/Contents/MacOS:/usr/local/bin:~/bin:/usr/local/sbin:${PATH}
#export DYLD_LIBRARY_PATH=”/usr/local/Cellar/mysql/5.5.14/lib:$DYLD_LIBRARY_PATH”

alias ll="ls -lpahtr"
alias lp="ls -p"
alias kp="ps auxwww"
alias ld="bundle exec thor"
alias ld="bundle exec cap"
#alias vim="mvim -v"
alias ports="sudo lsof -i -P | grep -i 'listen'"

#export VISUAL='mvim -v'
#export EDITOR='mvim -v'

# rg-caps Related
#ssh-add ~/.ssh/CENTARUS_PRIVATE_KEY
#ssh-add ~/.ssh/id_rsa
#.realgravity/rgi-keypair-20120125.pem

# Morpheus Related
export LOCAL_GEMS=/Users/pfarrell/proj/gems
alias ld='bundle exec thor '
alias m='bundle exec thor '
alias bcap='bundle exec cap '

export RAILS_ENV=production
[[ -s "$HOME/.rvm/scripts/rvm" ]] && . "$HOME/.rvm/scripts/rvm" # Load RVM function

rvm use ruby-1.9.3-p194

function local_gems() {
    export LOCAL_GEMS=/Users/pfarrell/proj/gems
      echo "LOCAL_GEMS = " $LOCAL_GEMS
}

function git_gems() {
    unset LOCAL_GEMS
      echo "LOCAL_GEMS = " $LOCAL_GEMS
}