alias gg='grep -R --line-number --exclude-dir .git --color'


if [ -f /usr/share/git-core/git-completion.bash ]; then
  . /usr/share/git-core/git-completion.bash
fi
