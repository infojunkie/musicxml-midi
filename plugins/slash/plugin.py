from MMA import pluginUtils as pu
import MMA.gbl as gbl

pu.setDescription("Define an extended slash chord.")
pu.setAuthor("Karim Ratib <karim.ratib@gmail.com> (https://github.com/infojunkie)")
pu.setSynopsis("""
    @Slash Chord/Bass

""")
pu.addArgument("Slash", None, "Slash chord to define.")
pu.setPluginDoc("""
This plugin defines an extended slash chord.
It extends the MMA slash chord definition to accept bass notes that are not in the chord's scale.

Written by Karim Ratib <karim.ratib@gmail.com> (https://github.com/infojunkie)
Version 1.0
""")

# ###################################
# # Entry points                    #
# ###################################

def printUsage():
    pu.printUsage()

def run(args):
    return

def trackRun(track, args):
    return

def dataRun(args):
    return
