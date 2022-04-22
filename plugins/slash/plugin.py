from MMA import pluginUtils as pu
import MMA.gbl as gbl
import MMA.chords as chords
from MMA.chordtable import chordlist

pu.setDescription("Define an extended slash chord.")
pu.setAuthor("Karim Ratib <karim.ratib@gmail.com> (https://github.com/infojunkie)")
pu.setSynopsis("""
    @Slash Chord/Bass

""")
pu.addArgument("Chord", None, "Slash chord to define.")
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
    name = args[0]
    if name.find('/') > 0:
        name, bass = name.split('/')
    else:
        return

    # Parse the original chord without bass.
    chord = chords.ChordNotes(name)

    # Get the interval between slash note and root.
    noteValues = {
        'Gb': -6,
        'G' : -5,
        'G#': -4, 'Ab': -4,
        'A' : -3,
        'A#': -2, 'Bb': -2,
        'B' : -1, 'Cb': -1,
        'B#':  0, 'C' :  0,
        'C#':  1, 'Db':  1,
        'D' :  2,
        'D#':  3, 'Eb':  3,
        'E' :  4, 'Fb':  4,
        'E#':  5, 'F' :  5,
        'F#':  6
    }
    interval = (noteValues[bass] - noteValues[chord.tonic]) % 12

    # Define a new chord with syntax "type\bass" to denote the slash chord.
    newName = chord.chordType + "\\" + str(interval)
    notes = [x for x in chordlist[chord.chordType][0]]
    scale = [x for x in chordlist[chord.chordType][1]]
    notes[0] = interval
    scale[0] = interval
    if newName not in chordlist:
        print("Defining new chord {}".format(newName))
        pu.addCommand("DefChord {} {} {}".format(
            newName,
            tuple(notes),
            tuple(scale)
        ))
        pu.sendCommands()

def trackRun(track, args):
    print("trackRun", track, args)

def dataRun(args):
    print("dataRun", args)
