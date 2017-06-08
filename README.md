# borg-backup.sh

A simple shell script for driving [Borg Backup][1].


## Usage

Make a borg-backup.conf from the provided template, e.g:

    ## Read from /etc/borg-backup.conf by default.
    ## Override by passing in CONFIG=/path/to.conf in the environment.
    ##
    ## This file is sourced by the shell.
    
    ###############################################################################
    ## Mandatory: Target destination for backups. Directory must exist.
    ##
    TARGET=backup@fancy-backup-server:/backups/${HOSTNAME}
    
    ###############################################################################
    ## Mandatory: A passphrase to derive an encryption key from.
    ##
    ## Be wary of permissions on this file.
    ##
    PASSPHRASE='ambiguous antelope capacitor paperclip'
    
    ###############################################################################
    ## Optional: Compression
    ##
    ## zlib is default, and is a good compromise between space and speed
    ## lz4 is somewhat weak, but very fast - a good choice for local backups or systems
    ## with fast links and slow CPUs.
    ##
    COMPRESSION=lz4
    
    ###############################################################################
    ## Optional: Global prune configuration
    ##
    PRUNE='-H 24 -d 14 -w 8 -m 6'
    
    ###############################################################################
    ## Mandatory: Backup name list
    ##
    BACKUPS='homes etc'
    
    ###############################################################################
    ## Mandatory: Backup configuration.
    ##
    ## One per backup name. Any borg create argument other than archive name is valid.
    ##
    BACKUP_homes='/home/freaky -e /home/freaky/Maildir/mutt-cache'
    BACKUP_etc='/etc /usr/local/etc'
    
    ###############################################################################
    ## Optional: Per-backup prune configuration.
    ##
    ## These override the global configuration for individual backups.
    #
    PRUNE_etc='--keep-hourly=72 --keep-daily=365'


This will produce two independent Borg archives.  If using a remote host over SSH,
consider [locking down the public key][2], and using [append-only mode][3] to limit
the damage a compromised client can cause.

Initialize repositories:

    $ borg-backup.sh init

And create your initial snapshots:

    $ borg-backup.sh create

Any time you want to make a new backup, re-run the create command.  Borg will create
a new snapshot, adding only new data.

To list archives:

    $ borg-backup.sh list

And to extract - in this case, `/etc/rc.conf` from the `etc` backup `etc-2017-02-21T20:00Z`:

    $ borg-backup.sh extract etc ::etc-2017-02-21T20:00Z etc/rc.conf --stdout

To prune old backups:

    $ borg-backup.sh prune

Note if you set the server to append-only mode, this will only mark data for deletion,
it will not free space.

For any Borg operation not covered explicitly, borg-backup.sh provides a `borg`
subcommand, which passes through the argument list to borg, having set up the
environment for the given repository.  Refer to the [Borg documentation][4] for detailed
usage instructions.

## Alternatives

If you want something a bit fancier, [borgmatic][5] is worth a look.


[1]: https://borgbackup.readthedocs.io/
[2]: https://borgbackup.readthedocs.io/en/stable/deployment.html#restrictions
[3]: https://borgbackup.readthedocs.io/en/stable/usage.html#append-only-mode
[4]: https://borgbackup.readthedocs.io/en/stable/usage.html
[5]: https://github.com/witten/borgmatic
