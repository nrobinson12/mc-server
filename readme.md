# Starting Fresh VPS with OVHcloud

## First Steps

Change passwords:

```sh
passwd # change current user password
sudo passwd # change root password
```

Update system

```sh
sudo apt update
sudo apt upgrade
```

References:

-   [OVHcloud Getting Started with a VPS](https://support.us.ovhcloud.com/hc/en-us/articles/360009253639-Getting-Started-with-a-VPS)

## Security

1. SSH Security

    Update `/etc/ssh/sshd_config` properties:

    ```sh
    Port <port> # change default port (remember to add -p <port> for future ssh)
    LoginGraceTime 2m # add this at the end of setup (in case of issues)
    PermitRootLogin no
    StrictModes yes
    PasswordAuthentication no # make sure you added ssh key to server
    ```

    Restart for changes to take affect:

    ```sh
    sudo systemctl restart sshd
    ```

2. Fail2ban

    ```sh
    sudo apt install fail2ban
    sudo cp /etc/fail2ban/jail.{conf,local}
    ```

    Add your local PC IP address to exclude from banning to `jail.local` file:

    ```sh
    ignoreip = 127.0.0.1/8 123.123.123.123
    ```

    Restart for changes to take affect:

    ```sh
    sudo systemctl restart fail2ban
    ```

3. iptables

    ```sh
    iptables -A INPUT -i lo -j ACCEPT # Allow all internal connections
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT # Allow established
    iptables -A INPUT -p tcp --dport <ssh-port> -j ACCEPT # Allow ssh
    iptables -A INPUT -p tcp --dport 25565 -j ACCEPT # Allow minecraft

    # VERIFY ABOVE BEFORE RUNNING THESE
    iptables -P INPUT DROP # Disallow all input not whitelisted
    iptables -P FORWARD DROP # Block all forwarding
    iptables -P OUTPUT ACCEPT # Allow all outgoing

    # Save rules, they won't persist after reboot
    sudo apt install iptables-persistent
    iptables-save > /etc/iptables/rules.v4
    ```

References:

-   [OVHcloud How to Secure a VPS](https://support.us.ovhcloud.com/hc/en-us/articles/4412351365139-How-to-Secure-a-VPS)
-   [How to Install and Configure Fail2ban on Ubuntu 20.04](https://linuxize.com/post/install-configure-fail2ban-on-ubuntu-20-04/)
-   [How to Secure Your SSH Connection in Ubuntu 18.04](https://support.us.ovhcloud.com/hc/en-us/articles/115001669550)
-   [IP Tables for Minecraft](https://gist.github.com/Maxopoly/6c925a1f18f9e2f3b9818d1c1582b17e)

# Troubleshooting

## Windows Subsystem for Linux (WSL)

-   Learned that the ip for wsl changes, it is not static
-   Thus you can't add an iptable rule in the server for it
-   Also the ssh uses the computer ip address, not the wsl ip address
-   So use your public ip from windows

## iptables

```sh
# list rules with line numbers
iptables -L --line-numbers

# watch the specific rule for it working
watch -n 0.5 iptables -L INPUT <line-number> -nvx

# change specific rule
iptables -R INPUT <line-number> ...
```

## Locked Out

-   Locked out of vps, can't ssh into it anymore
-   Reboot in rescue mode
-   Will get email with user & pass to ssh into
-   [OVHcloud How to Recover Your VPS in Rescue Mode](https://support.us.ovhcloud.com/hc/en-us/articles/360010553920-How-to-Recover-Your-VPS-in-Rescue-Mode)

# Setting up Minecraft Paper Server on VPS

## Initial

```sh
sudo apt install screen nano wget git # install packages
sudo apt install openjdk-17-jdk # install java
sudo adduser minecraft --disabled-login --disabled-password # create user to run server
```

## Paper Server

Switch to `minecraft` user and setup the `paper` directory. Use the latest paper download from [papermc.io](https://papermc.io/downloads).

```sh
mkdir paper
cd paper
curl -L -o paper.jar https://api.papermc.io/v2/projects/paper/versions/1.19.2/builds/211/downloads/paper-1.19.2-211.jar
```

Run server and then sign the EULA

```sh
java -jar paper.jar
perl -pi -e 's/false/true/' eula.txt
```

## Easy Startup / Backup Scripts

Curtesy [Brandon Dusseau](https://github.com/BrandonDusseau/minecraft-scripts).

-   use `startmc.sh` and `backup.sh` for starting the server and creating backups.

`startmc.sh` uses screen, some useful commands:

```sh
screen -ls # list screens
screen -S <screen-name> # create screen
screen -r <id> # attach to screen (detach: ctrl + a + d)
screen -XS <id> quit # kill a screen
```

Setup cron jobs (make sure you are user `minecraft`):

```sh
crontab -e
```

Inside the crontab file:

```sh
# automatically start mc server on reboot
@reboot sleep 30 && /home/minecraft/paper/startmc.sh

# backup every sunday at midnight
0 0 * * 0 /home/minecraft/paper/backup.sh -s
```

## References

-   [Tutorial - How to create a Minecraft server on a VPS](https://docs.ovh.com/us/en/vps/create-minecraft-server-on-vps/)
-   [Set Up PaperMC Server on Linux](https://rwx.gg/services/mc/paper/tasks/setup/)
-   [PaperMC Downloads](https://papermc.io/downloads)
-   [Brandon Dusseau minecraft-scripts](https://github.com/BrandonDusseau/minecraft-scripts)

# Extra Information

## Configurations

Setup `server.properties`:

```sh
motd=<Your Server Name>
difficulty=normal
view-distance=16
server-ip=<Your Server IP>
simulation-distance=10
white-list=true # make sure you are whitelisted before setting this
enforce-whitelist=true
spawn-protection=0 # anyone can build in spawn
```

You can add a `server-icon.png` into the base `paper` folder to change the icon that shows up for the server. This icon needs to be 64 x 64 pixels.

In server

```sh
op <user>
/gamerule playersSleepingPercentage -1 # one player sleep
```

Options for `spigot.yml`:

```sh
entity-tracking-range:
    players: 144
    animals: 64
    monsters: 64
    misc: 48
    other: 144
```

## Transferring Vanilla -> Paper World

-   Put `DIM-1` into it's own folder `world_nether`
-   Put `DIM1` into it's own folder `world_the_end`
-   Make general overworld folder with remaining files `world`
-   Then tar it:

    ```sh
    tar --mode="a+rw" -cf world.tar -C world .
    gzip -fq world.tar
    rsync -raz -e 'ssh -p <port>' /local/path/to/world.tar.gz ubuntu@<vps-ip>:/home/ubuntu/world.tar.gz
    ```

-   Now the world should be in your server, just move it to the base `paper` folder (as root user):

    ```sh
    mv /home/ubuntu/world.tar.gz /home/minecraft/world.tar.gz
    ```

-   Unzip the world and remove the zipped file (as minecraft user):

    Make sure to stop the server first: `screen -r`, `stop`, ctrl + d

    ```sh
    tar -xf world.tar.gz
    rm world.tar.gz
    ```

## Backing Up Server

```sh
tar --exclude='world' --exclude='world_nether' --exclude='world_the_end' --exclude='backups' --mode="a+rw" -cf /home/ubuntu/serverbackup.tar -C /home/minecraft/ paper 2>&1
gzip -fq /home/ubuntu/serverbackup.tar 2>&1
```
