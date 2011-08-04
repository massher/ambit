# The Ambit Function Library File

function Validate {
    [ -d "$1" ] && Results="$1" && return 0
    ItsType=$(type -t $1 || return 1)
    [[ "${ItsType}" == +(file) ]] && Results=$( type -P $1 ) && return 0
    [[ "${ItsType}" == +(alias|keyword|function|builtin)  ]] && return 1
}

function Create_DownHosts {
    DownClean=$(${sed} -e 's/\#.*$//g' -e '/^$/d' -e 's/\(^.*\)\ /\1/g' \
        <(${cat} "$AllFiles/hosts/down"))
    DownHosts=$(echo "$DownClean" | LC_ALL=C ${sort} | ${uniq})

    return 0
}


# Substitute Curly Braces for Brackets
function BracketToBrace {
    local BtoB=$(echo "$1" | ${sed} -e 's/\[/\{/g' -e 's/\]/\}/g') && echo $BtoB

    return 0
}

# Swap Spaces for Newlines - Swap Pluses for Spaces
function SwapOut {
    for SingleEntry in "$@"
    do
        echo "$SingleEntry" | ${sed} -e 's/\ /\n/g' -e 's/+/\ /g'
    done

    return 0
}

# Clean TXT Record Response
function Clean_Text {
    ${sed} 's/^.*\"\(.*\)\"$/\1/' <(${host} -t txt $1) || return 1
    return 0
}

# HostGroup Creation 
function Create_Host_Group {
    read -e -p 'HostGroup Name : '    SetName    2>&1
    read -e -p 'HostGroup Summary : ' SetSummary 2>&1
    ${touch} $HostPath/$SetName || return 1

    echo -e "#\n# Summary - $SetSummary \n#">$HostPath/$SetName \
        || return 1

    echo "Enter Hostnames Below [Ctrl-d to End]: " \
        && SetEntries="$(${cat} /dev/stdin)" \
        && SwapOut "$SetEntries" >> $HostPath/$SetName \
        && exit 0 \
        || ${rm} -rf $HostPath/$SetName
}

# HostGroup Listing
function List_Host_Group {
    [ -n "Domain" ] \
        && DnsServer=$(${host} -t ns $Domain | ${head} -1 | ${sed} -e 's/^.*\ //g') \
        && NetResult=$(${sed} -e 's/\..*text\ /:#/g' \
            <(${grep} ^.*desc.*tex.*$ \
                <(${host} -t txt -l $Domain $DnsServer)))

    AllResults=$(${grep} -r -H Summary $AllFiles/hosts \
        | ${sed} -e 's/^.*hosts\/\(.*:#\)\ Summary\ -\ \(.*$\)/\1 \2/g')
    UsrResults=$(${grep} -r -H Summary $UsrFiles/hosts \
        | ${sed} -e 's/^.*hosts\/\(.*:#\)\ Summary\ -\ \(.*$\)/\1 \2/g') 

    [ -n "$NetResult" ] \
        && echo -e "\nNetwork HostGroup[s]\n--------------------" \
        && echo "$NetResult"  | ${sort} | ${column} -s# -t
    [ -n "$AllResults" ] \
        && echo -e   "\nSystem HostGroup[s]\n-------------------" \
        && echo "$AllResults" | ${sort} | ${column} -s# -t
    [ -n "$UsrResults" ] \
        && echo -e       "\nUser HostGroup[s]\n-----------------" \
        && echo "$UsrResults" | ${sort} | ${column} -s# -t
    echo

   exit 0
}

# HostGroup Editing
function Edit_Host_Group {
    vi $HostPath/$3 
    
    exit 0
}

# HostGroup Removal
function Remove_Host_Group {
    rm -rf $HostPath/$3 && echo "HostGroup '$3' Has Been Deleted"

    exit 0
}

# Options Listing
function List_Options {
    local AllOptions=$(${grep} ^[A-Z].*\=\".*\"[\ ]*$ $AllConf || echo "NONE")
    local UsrOptions=$(${grep} ^[A-Z].*\=\".*\"[\ ]*$ $UsrConf || echo "NONE")

    echo -e "\nSystem Options\n--------------\n$AllOptions"
    echo -e     "\nUser Options\n------------\n$UsrOptions"
    echo

    exit 0
}

# Options Editing
function Edit_Options {
    [ -z "$3" ] && exit 1

    TargetOption=$(${grep} -h ^$3.*\=\".*\"[\ ]*$ $AllConf $UsrConf | ${tail} -1)
    OptionValue=$(${sed} -e 's/^.*\"\(.*\)\".*$/\1/g' <(echo "$TargetOption"))

    echo -e    "Updating Option : $3"
    echo       "Current Value   : $OptionValue"
    read -e -p 'Enter New Value : ' UsrOptionValue 2>&1

    [ -z "$UsrOptionValue" ] \
        && ${grep} -v $3 $UsrConf > $UsrConf.new \
        && UsrOption=$(echo "$3=\"\"") \
        && echo "$UsrOption" >> $UsrConf.new \
        && ${mv} $UsrConf{.new,} \
        && echo -e "$UsrOption" \
        && exit 0

    [ -f "$UsrConf" ] \
        && ${grep} -v $3 $UsrConf > $UsrConf.new \
        && UsrOption=$(echo "$3=\"$UsrOptionValue\"") \
        && echo "$UsrOption" >> $UsrConf.new \
        && ${mv} $UsrConf{.new,} \
        && echo -e "$UsrOption" \
        && exit 0

    exit 0
}

# HostGroup or Command?
function Host_Group_Or_Command {
    [[ $(echo "$@" | ${grep} \ ) ]] \
        && TheString="$(echo $@ | ${tr} -s '\ ' '\+')" \
        && ImACmd="yes" \
        && PATH=$PATH:/usr/sbin:/sbin \
        || TheString="$(echo $@)"

    return 0
}
    
# The Expansion Loop
function Expansion_Loop {
    TheExtent=($(eval echo $TheString))

    for index in ${!TheExtent[*]}
    do
        # Are We Command Expanding?
        [ -n "$ImACmd" ] && $(SwapOut ${TheExtent[$index]}) \
            && continue

        # Check PWD for HostGroup File
        [ -f ${TheExtent[$index]} ] \
            && ${egrep} -v '^#|^\s*$' ${TheExtent[$index]} \
            | while read entry 
            do
                entry="$(BracketToBrace $entry)"
                eval echo $entry | ${tr} -s '\ ' '\n'
            done && continue

        # Check AllFiles For HostGroup File
        [ -f $AllFiles/hosts/${TheExtent[$index]} ] \
            && ${egrep} -v '^#|^\s*$' $AllFiles/hosts/${TheExtent[$index]} \
            | while read entry 
            do
                entry="$(BracketToBrace $entry)"
                eval echo $entry | ${tr} -s '\ ' '\n'
            done && continue

        # Check UsrFiles For HostGroup File
        [ -f $UsrFiles/hosts/${TheExtent[$index]} ] \
            && ${egrep} -v '^#|^\s*$' $UsrFiles/hosts/${TheExtent[$index]} \
            | while read entry 
            do 
                entry="$(BracketToBrace $entry)"
                eval echo $entry | ${tr} -s '\ ' '\n'
            done && continue

        # If TheString Ends w/ a Match of Domain Set SkipDomain
        [[ $(echo "${TheExtent[$index]}" | ${grep} ^.*[\.].*[\.].*$) ]] \
            && SkipDomain="yes"

        # Lookup HostGroup in DNS
        [[ -n "$Domain" && -z "$SkipDomain" ]] \
            && [[ $(Clean_Text ${TheExtent[$index]}.$Domain \
                | ${grep} -v "found") ]] \
            && DNSExtent=$(Clean_Text ${TheExtent[$index]}.$Domain)

        [ -n "$DNSExtent" ] \
            && eval echo $(BracketToBrace $DNSExtent) | ${tr} -s '\ ' '\n' \
            && unset DNSExtent \
            && continue

        # At This Point Just Expand The Extent
        eval echo ${TheExtent[$index]}
    done
}

# Bail Gracefully
function Failed {
    MyNameIs=$(echo $MyNameIs | sed -e 's/^[a-z]?/[A-Z]/g')
    ${logger} -i -t $MyNameIs -- "Error - $@"
    echo "$@"
    exit 2
}
