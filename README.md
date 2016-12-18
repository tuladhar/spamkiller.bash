# spamkiller.bash

**NOTE:** Designed to work only on cPanel servers.

The script searches for known spamming scripts (see: `SIGNATURES`, `FILEPATTERN`) within users directories where spam emails are originating from. If such scripts are detected then they are printed and mode 000 is applied.

## Install
```
curl -sO https://raw.githubusercontent.com/tuladhar/spamkiller/master/spamkiller.bash
```

## Usage
```
cat spamkiller.bash | ssh -T <your-cpanel-server>
```
or
```
scp spamkiller.bash <cpanel-server>:/tmp
ssh <cpanel-server>
bash /tmp/spamkiller.bash
```

## Signatures in-use
Add more signature here as regex.
```
SIGNATURES='\$t60=\"|base64_decode\";return'
```

## File Patterns
Add more file pattern here as regex to search more scripts for above signatures
```
FILEPATTERN=".*(php|php\.suspected)$"
```

## Authors
* Puru Tuladhar
