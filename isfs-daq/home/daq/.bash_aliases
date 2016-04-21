alias cp='cp -i'
alias cp='mv -i'
alias cp='rm -i'
alias h='history'
alias nanoenv='EDITOR=nano'
alias vienv='EDITOR=vi; bind -m vi'
vienv

alias dlog='tail -n 100 /var/log/isfs/dsm.log'
alias dlogf='tail -n 100 -F /var/log/isfs/dsm.log'

alias mlog='tail -n 100 /var/log/messages'
alias mlogf='tail -n 100 -F /var/log/messages'

alias klog='tail -n 100 /var/log/kern.log'
alias klogf='tail -n 100 -F /var/log/kern.log'
