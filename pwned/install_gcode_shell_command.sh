#!/bin/sh
# Installa gcode_shell_command.py nelle extras di Klipper.
# Eseguire SULLA BOARD via SSH. Nessuna connessione internet richiesta:
# il file e' incorporato qui dentro.

set -e

EXTRAS_DIR="/usr/prog/klipper/klippy/extras"
TARGET="$EXTRAS_DIR/gcode_shell_command.py"

if [ ! -d "$EXTRAS_DIR" ]; then
    echo "ERRORE: $EXTRAS_DIR non esiste su questo sistema."
    echo "Cerco la cartella extras corretta..."
    find / -type d -name "extras" -path "*klipper*" 2>/dev/null
    exit 1
fi

if [ -f "$TARGET" ]; then
    echo "Trovato gia' un file esistente in $TARGET, ne faccio un backup..."
    cp "$TARGET" "$TARGET.bak.$(date +%s)"
fi

cat > "$TARGET" << 'PYEOF'
# Run a shell command via gcode
#
# Copyright (C) 2019  Eric Callahan <arksine.code@gmail.com>
#
# This file may be distributed under the terms of the GNU GPLv3 license.
import logging
import os
import shlex
import subprocess


class ShellCommand:
    def __init__(self, config):
        self.name = config.get_name().split()[-1]
        self.printer = config.get_printer()
        self.gcode = self.printer.lookup_object("gcode")
        cmd = config.get("command")
        cmd = os.path.expanduser(cmd)
        cmd = os.path.expandvars(cmd)
        self.command = shlex.split(cmd)
        self.timeout = config.getfloat("timeout", 2.0, above=0.0)
        self.verbose = config.getboolean("verbose", True)
        self.proc_fd = None
        self.partial_output = ""
        self.gcode.register_mux_command(
            "RUN_SHELL_COMMAND",
            "CMD",
            self.name,
            self.cmd_RUN_SHELL_COMMAND,
            desc=self.cmd_RUN_SHELL_COMMAND_help,
        )

    def _process_output(self, eventime):
        if self.proc_fd is None:
            return
        try:
            data = os.read(self.proc_fd, 4096)
        except Exception:
            pass
        data = self.partial_output + data.decode()
        if "\n" not in data:
            self.partial_output = data
            return
        elif data[-1] != "\n":
            split = data.rfind("\n") + 1
            self.partial_output = data[split:]
            data = data[:split]
        else:
            self.partial_output = ""
        self.gcode.respond_info(data)

    cmd_RUN_SHELL_COMMAND_help = "Run a linux shell command"

    def cmd_RUN_SHELL_COMMAND(self, params):
        gcode_params = params.get("PARAMS", "")
        gcode_params = shlex.split(gcode_params)
        reactor = self.printer.get_reactor()
        try:
            proc = subprocess.Popen(
                self.command + gcode_params,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
            )
        except Exception:
            logging.exception("shell_command: Command {%s} failed" % (self.name))
            raise self.gcode.error("Error running command {%s}" % (self.name))
        if self.verbose:
            self.proc_fd = proc.stdout.fileno()
            self.gcode.respond_info("Running Command {%s}...:" % (self.name))
            hdl = reactor.register_fd(self.proc_fd, self._process_output)
        eventtime = reactor.monotonic()
        endtime = eventtime + self.timeout
        complete = False
        while eventtime < endtime:
            eventtime = reactor.pause(eventtime + 0.05)
            if proc.poll() is not None:
                complete = True
                break
        if not complete:
            proc.terminate()
        if self.verbose:
            if self.partial_output:
                self.gcode.respond_info(self.partial_output)
                self.partial_output = ""
            if complete:
                msg = "Command {%s} finished\n" % (self.name)
            else:
                msg = "Command {%s} timed out" % (self.name)
            self.gcode.respond_info(msg)
            reactor.unregister_fd(hdl)
            self.proc_fd = None


def load_config_prefix(config):
    return ShellCommand(config)
PYEOF

chmod 644 "$TARGET"
echo "OK: installato in $TARGET"
echo "Ora aggiungi al printer.cfg una sezione tipo:"
echo ""
echo "[gcode_shell_command NOME]"
echo "command: /path/allo/script.sh"
echo "timeout: 2"
echo "verbose: True"
echo ""
echo "poi esegui RESTART in Klipper."