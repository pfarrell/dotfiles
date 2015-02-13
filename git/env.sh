alias gg='grep -R --line-number --exclude-dir .git --color'
alias gpr='git pull --rebase'
alias gnb='git checkout -b'


if [ -f /usr/share/git-core/git-completion.bash ]; then
  . /usr/share/git-core/git-completion.bash
fi

if [ -f /usr/local/git/contrib/completion/git-completion.bash ]; then
  . /usr/local/git/contrib/completion/git-completion.bash
fi

if [ -f /Library/Developer/CommandLineTools/usr/share/git-core/git-completion.bash ]; then
  . /Library/Developer/CommandLineTools/usr/share/git-core/git-completion.bash
fi

if [ -f /Library/Developer/CommandLineTools/usr/share/git-core/git-prompt.sh ]; then
  . /Library/Developer/CommandLineTools/usr/share/git-core/git-prompt.sh
fi

if [ -f /usr/local/Cellar/git/2.2.1/etc/bash_completion.d/git-prompt.sh ]; then
  . /usr/local/Cellar/git/2.2.1/etc/bash_completion.d/git-prompt.sh
fi

if [ -f /usr/local/git/contrib/completion/git-prompt.sh ]; then
  . /usr/local/git/contrib/completion/git-prompt.sh
fi

if [ -f /usr/local/Cellar/git/2.2.1/etc/bash_completion.d/git-completion.bash ]; then
  . /usr/local/Cellar/git/2.2.1/etc/bash_completion.d/git-completion.bash
fi
