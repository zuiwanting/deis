
import StringIO
import select
import socket
import sys
import time

import paramiko


def connect_ssh(username, hostname, port, key,
                timeout=120, attempts=10):
    key_f = StringIO.StringIO(key)
    pkey = paramiko.RSAKey.from_private_key(key_f)
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    interval = int(timeout / attempts)
    for _ in range(attempts):
        try:
            ssh.connect(hostname, username=username, pkey=pkey)
            break
        except paramiko.AuthenticationException as e:
            raise paramiko.AuthenticationException(e)
        except socket.error:
            time.sleep(interval)
    else:
        raise RuntimeError('SSH Connection Error')
    return ssh


def exec_ssh(ssh, command, pty=False):
    tran = ssh.get_transport()
    chan = tran.open_session()
    # NOTE: pty breaks line ordering on commands like apt-get
    if pty:
        chan.get_pty(term='vt100', width=80, height=24)
    chan.exec_command(command)
    output = read_from_ssh(chan)
    exit_status = chan.recv_exit_status()
    return output, exit_status


def interact_ssh(ssh, command=None, pty=True):
    try:
        tran = ssh.get_transport()
        chan = tran.open_session()
        posix_shell(chan)
    finally:
        ssh.close()


def read_from_ssh(chan):
    output = ''
    while True:
        r, w, e = select.select([chan], [], [], 10)  # @UnusedVariable
        if r:
            got_data = False
            if chan.recv_ready():
                data = r[0].recv(4096)
                if data:
                    got_data = True
                    output += data
                    # print("stdout => ", data)
            if chan.recv_stderr_ready():
                data = r[0].recv_stderr(4096)
                if data:
                    got_data = True
                    output += data
                    # print("stderr => ", data)
            if not got_data:
                return output


def posix_shell(chan):
    import select

    # oldtty = termios.tcgetattr(sys.stdin)
    # try:
    # tty.setraw(sys.stdin.fileno())
    # tty.setcbreak(sys.stdin.fileno())
    chan.settimeout(0.0)

    while True:
        r, w, e = select.select([chan, sys.stdin], [], [])
        if chan in r:
            try:
                x = chan.recv(1024)
                if len(x) == 0:
                    print '\r\n*** EOF\r\n',
                    break
                sys.stdout.write(x)
                sys.stdout.flush()
            except socket.timeout:
                pass
        if sys.stdin in r:
            x = sys.stdin.read(1)
            if len(x) == 0:
                break
            chan.send(x)

    # finally:
    #     termios.tcsetattr(sys.stdin, termios.TCSADRAIN, oldtty)
