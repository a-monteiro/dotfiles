
#zmodload zsh/datetime
#setopt PROMPT_SUBST
#PS4='+$EPOCHREALTIME %N:%i> '
#
#logfile=$(mktemp zsh_profile.XXXXXXXX)
#echo "Logging to $logfile"
#exec 3>&2 2>$logfile
#
#setopt XTRACE

source /opt/homebrew/opt/antidote/share/antidote/antidote.zsh
zstyle ':omz:update' mode disabled
zstyle ':antidote:bundle' use-friendly-names 'yes'
zstyle ':autocomplete:*' default-context history-incremental-search-backward
ZSH_DISABLE_COMPFIX=true
# set omz variables prior to loading omz plugins
ZSH=$(antidote path ohmyzsh/ohmyzsh)
ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/oh-my-zsh"
[[ -d $ZSH_CACHE_DIR ]] || mkdir -p $ZSH_CACHE_DIR

if type brew &>/dev/null; then
  FPATH=/opt/homebrew/share/zsh-completions:/opt/homebrew/share/zsh/site-functions:$FPATH

  autoload -Uz compinit
  compinit
fi
antidote load 

#source <(antidote init)

autoload -Uz promptinit && promptinit
prompt powerlevel10k

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# get zsh complete kubectl
source <(kubectl completion zsh)

# get zsh completion for stern
source <(stern --completion=zsh)

#alias kubectl=kubecolor
# make completion work with kubecolor
#compdef kubecolor=kubectl

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
expand-or-complete-with-dots() {
  echo -n "\e[31m...\e[0m"
  zle expand-or-complete
  zle redisplay
}
zle -N expand-or-complete-with-dots
bindkey "^I" expand-or-complete-with-dots

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

unalias gsts

export PATH="${PATH}:${HOME}/.krew/bin"

function awslogin {
 gsts --force --aws-region eu-west-1 --aws-role-arn arn:aws:iam::118330671040:role/SSOAdministrator --sp-id 362114136470 --idp-id C02k0bpbn --json --aws-profile=default --aws-shared-credentials-file /Users/andre/.aws/gsts-credentials
 #cp ~/.aws/gsts-credentials ~/.aws/credentials
}

function podzone {
   kubectl get pod $2 -n $1 -o jsonpath='{.spec.nodeName}' | xargs kubectl get node -o jsonpath='{.metadata.labels.failure-domain\.beta\.kubernetes\.io/zone}'
 }

function timezsh {
  shell=${1-$SHELL}
  for i in $(seq 1 10); do /usr/bin/time $shell -i -c exit; done
}

function dssh {
  SSH_KEY=~/.ssh/id_rsa # Default location, but you can change this to a different key if you prefer. Must have a matching `.pub` public key alongside it.
  AWS_DEFAULT_REGION=eu-west-1
  USER=ubuntu
  if [ -z "$1" ]; then echo "Usage: dssh instance-name" && return 1; fi
  INSTANCE_DETAILS=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$1" --output text --query 'Reservations[0].Instances[0].[InstanceId,Placement.AvailabilityZone]')
  if [ $? -ne 0 ] ; then echo "Failed to describe instances. Check you are logged into AWS with MFA." && return 1; fi
  if [ "$INSTANCE_DETAILS" = "None" ] ; then echo "Caot find instance $1. Check you are logged in to the correct AWS account and the instance exists." && return 1; fi
  aws ec2-instance-connect send-ssh-public-key \
    --instance-id $(echo "$INSTANCE_DETAILS" | awk '{print $1}') \
    --availability-zone $(echo "$INSTANCE_DETAILS" | awk '{print $2}') \
    --instance-os-user "$USER" \
    --ssh-public-key "file://$SSH_KEY.pub" \
    || (echo "Failed to send public key file://$SSH_KEY.pub to AWS" && return 1)
  ssh -i "$SSH_KEY" "$USER@$1"
}

function kssh {
  SSH_KEY=~/.ssh/id_rsa # Default location, but you can change this to a different key if you prefer. Must have a matching `.pub` public key alongside it.
  AWS_DEFAULT_REGION=eu-west-1
  USER=ec2-user
  if [ -z "$1" ]; then echo "Usage: kssh instance-name" && return 1; fi
  INSTANCE_DETAILS=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$1" --output text --query 'Reservations[0].Instances[0].[InstanceId,Placement.AvailabilityZone,PrivateIpAddress]')
  if [ $? -ne 0 ] ; then echo "Failed to describe instances. Check you are logged into AWS with MFA." && return 1; fi
  if [ "$INSTANCE_DETAILS" = "None" ] ; then echo "Cannot find instance $1. Check you are logged in to the correct AWS account and the instance exists." && return 1; fi
  aws ec2-instance-connect send-ssh-public-key \
    --instance-id $(echo "$INSTANCE_DETAILS" | awk '{print $1}') \
    --availability-zone $(echo "$INSTANCE_DETAILS" | awk '{print $2}') \
    --instance-os-user "$USER" \
    --ssh-public-key "file://$SSH_KEY.pub" \
    || (echo "Failed to send public key file://$SSH_KEY.pub to AWS" && return 1)
  kubectl ssh-jump --cleanup-jump -i "$SSH_KEY" -u "$USER" "$(echo "$INSTANCE_DETAILS" | awk '{print $3}')"
}

function drsync {
  SSH_KEY=~/.ssh/id_rsa # Default location, but you can change this to a different key if you prefer. Must have a matching `.pub` public key alongside it.
  AWS_DEFAULT_REGION=eu-west-1
  USER=ubuntu
  INSTANCE_NAME=$(echo $2 | cut -d ":" -f 1)
  if [ -z "$INSTANCE_NAME" ]; then echo "Usage: dssh instance-name" && return 1; fi
  INSTANCE_DETAILS=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$INSTANCE_NAME" --output text --query 'Reservations[0].Instances[0].[InstanceId,Placement.AvailabilityZone]')
  if [ $? -ne 0 ] ; then echo "Failed to describe instances. Check you are logged into AWS with MFA." && return 1; fi
  if [ "$INSTANCE_DETAILS" = "None" ] ; then echo "Cannot find instance $INSTANCE_NAME. Check you are logged in to the correct AWS account and the instance exists." && return 1; fi
  aws ec2-instance-connect send-ssh-public-key \
    --instance-id $(echo "$INSTANCE_DETAILS" | awk '{print $1}') \
    --availability-zone $(echo "$INSTANCE_DETAILS" | awk '{print $2}') \
    --instance-os-user "$USER" \
    --ssh-public-key "file://$SSH_KEY.pub" \
    || (echo "Failed to send public key file://$SSH_KEY.pub to AWS" && return 1)
  rsync -azP -e "ssh -i $SSH_KEY" $1 "$USER@$2"
  # scp -i "$SSH_KEY" -r $1 "$SSH_USER@$2"
}

function databricks_ssh {
    PUBLIC_KEY="~/.ssh/id_rsa.pub"
    PRIVATE_KEY="~/.ssh/id_rsa"
    if [ "$#" -ne 3 ]; then echo "Usage: databricks_ssh cluster-name driver|executors[0]|executors[1]|... prod"  && return 1; fi
    IP=$(databricks --profile "$3" clusters get --cluster-name "$1" | jq -e -r ".$2.host_private_ip")
    if [ $? -ne 0 ] ; then echo "Failed to get cluster IP" && return 1; fi
    echo "Connecting to $IP"
    kubectl ssh-jump -u ubuntu -i $PRIVATE_KEY -p $PUBLIC_KEY --port 2200 "$IP"
}

function uberwatch {
    # call: uberwatch <interval> <command>
    while true; do
        echo "------------------------------------------------------------------------------------------------------------------------------------------";"${@:2}";
        sleep $1;
    done
}
# Add pipenv autocompletion
#compdef pipenv

_pipenv_completion() {
    local -a completions
    local -a completions_with_descriptions
    local -a response
    (( ! $+commands[pipenv] )) && return 1

    response=("${(@f)$(env COMP_WORDS="${words[*]}" COMP_CWORD=$((CURRENT-1)) _PIPENV_COMPLETE=zsh_complete pipenv)}")

    for type key descr in ${response}; do
        if [[ "$type" == "plain" ]]; then
            if [[ "$descr" == "_" ]]; then
                completions+=("$key")
            else
                completions_with_descriptions+=("$key":"$descr")
            fi
        elif [[ "$type" == "dir" ]]; then
            _path_files -/
        elif [[ "$type" == "file" ]]; then
            _path_files -f
        fi
    done

    if [ -n "$completions_with_descriptions" ]; then
        _describe -V unsorted completions_with_descriptions -U
    fi

    if [ -n "$completions" ]; then
        compadd -U -V unsorted -a completions
    fi
}

compdef _pipenv_completion pipenv;


#eval "$(_PIPENV_COMPLTE=zsh_source pipenv)"
export LANG=en_US.UTF-8
export EDITOR=nvim
# ALIASES
alias zshconfig="vi ~/.zshrc"
alias curl="curl -s -S"
alias vi="nvim"
alias vim="nvim"

_gt_yargs_completions()
{
  local reply
  local si=$IFS
  IFS=$'
' reply=($(COMP_CWORD="$((CURRENT-1))" COMP_LINE="$BUFFER" COMP_POINT="$CURSOR" /opt/homebrew/bin/gt --get-yargs-completions "${words[@]}"))
  IFS=$si
  _describe 'values' reply
}
compdef _gt_yargs_completions gt

export JAVA_HOME=$(/usr/libexec/java_home)
#unsetopt XTRACE
#exec 2>&3 3>&-

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/andre/Downloads/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/andre/Downloads/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/andre/Downloads/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/andre/Downloads/google-cloud-sdk/completion.zsh.inc'; fi
alias config='/usr/bin/git --git-dir=/Users/andre/.cfg/ --work-tree=/Users/andre'

export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

export GOPRIVATE="github.com/duneanalytics/*,github.com/a-monteiro/*"


# Fix for _p9k_worker_stop:5: failed to close file descriptor 13: bad file descriptor
unset ZSH_AUTOSUGGEST_USE_ASYNC

