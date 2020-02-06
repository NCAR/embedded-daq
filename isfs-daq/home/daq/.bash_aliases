alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
alias h='history'
alias emacsenv='export EDITOR=emacs; bind -m emacs'
alias nanoenv='export EDITOR=nano'
alias vienv='export EDITOR=vi; bind -m vi'
vienv

alias dlog='tail -n 100 /var/log/isfs/dsm.log'
alias dlogf='tail -n 100 -F /var/log/isfs/dsm.log'

alias mlog='tail -n 100 /var/log/messages'
alias mlogf='tail -n 100 -F /var/log/messages'

alias klog='tail -n 100 /var/log/kern.log'
alias klogf='tail -n 100 -F /var/log/kern.log'

alias cs='chronyc sources'

# show real-time class and priority of processes and their threads
alias psrt='ps -eTo pid,user,%cpu,%mem,class,rtprio,comm'
alias psrtg='ps -eTo pid,user,%cpu,%mem,class,rtprio,comm | grep -e PID -e '

# ISFS data aliases
alias nr01='data_dump -i -1,0x814c-0x814f -p'
alias tsoil='data_dump -i -1,0x8120-0x8123 -p'
alias gsoil='data_dump -i -1,0x8124-0x8127 -p'
alias qsoil='data_dump -i -1,0x8128-0x812b -p'
alias tp01='data_dump -i -1,0x812c-0x812f -p'
alias gps='data_dump -i -1,11-12 -p'
alias trh='data_dump -i -1,21 -p'
alias ptb='data_dump -i -1,23 -p'
alias 2d='data_dump -i -1,101 -p'
alias csat='data_dump -i -1,41 -p'
alias ec='data_dump -i -1,43 -p'
alias ott='data_dump -i -1,9 -p'
alias pmon='data_dump -i -1,60-65 -p'
