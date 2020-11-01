alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
alias psg='ps ax | grep '
alias h='history'
alias nanoenv='export EDITOR=nano'
alias vienv='export EDITOR=vi; bind -m vi'
vienv

alias dlog='tail -n 100 /var/log/ads/dsm.log'
alias dlogf='tail -n 100 -F /var/log/ads/dsm.log'

alias mlog='tail -n 100 /var/log/messages'
alias mlogf='tail -n 100 -F /var/log/messages'

alias klog='tail -n 100 /var/log/kern.log'
alias klogf='tail -n 100 -F /var/log/kern.log'

# show real-time class and priority of processes and their threads
alias psrt='ps -eTo pid,user,%cpu,%mem,class,rtprio,comm'
alias psrtg='ps -eTo pid,user,%cpu,%mem,class,rtprio,comm | grep -e PID -e '

# Display a debian package changelog, e.g or nidas, nidas-modules-viper.
# Packages such as ads-daq, which don't provide source, don't have useful
# info in their changelog.
alias chglog='xargs -I% -- sh -c "zmore /usr/share/doc/%/changelog*.gz" <<<'

