from MMA import pluginUtils as pu
import MMA.gbl as gbl

pu.setDescription("Define a MIDI tuning in Scala format.")
pu.setAuthor("Karim Ratib <karim.ratib@gmail.com> (https://github.com/infojunkie)")
pu.setSynopsis("""
    @Tuning Key Delta

""")
pu.addArgument("Key", None, "MIDI key to tune.")
pu.addArgument("Delta", None, "Cents difference from the regular 12TET tuning of Key.")
pu.setPluginDoc("""
This plugin defines a MIDI note tuning. It outputs a MIDI MTS SysEx message.

    @Tuning Key Delta
  where
    - Key is a MIDI key (0-127)
    - Delta is a cents difference from the regular 12TET tuning of Key

Written by Karim Ratib <karim.ratib@gmail.com> (https://github.com/infojunkie)
Version 1.0
""")

# ###################################
# # Entry points                    #
# ###################################

def printUsage():
    pu.printUsage()

def run(args):
    print("run", args)

def trackRun(track, args):
    print("trackRun", track, args)

def dataRun(args):
    print("dataRun", args)
