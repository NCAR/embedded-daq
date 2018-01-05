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
alias psrtg='ps -eTo pid,user,%cpu,%mem,class,rtprio,comm | grep'

