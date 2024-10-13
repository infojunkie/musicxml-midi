import util from 'util'
import { createRequire } from 'module'
import fs from 'fs'
const require = createRequire(import.meta.url)
const exec = util.promisify(require('child_process').exec)

describe('midi-file', () => {
  test('should convert incoming MIDI files to JSON', async () => {
    const execResult = await exec('node src/js/midi-file.js < test/data/midi-timemap.test.mid')
    const json = JSON.parse(execResult.stdout)
    expect(json.header.numTracks).toEqual(3)
  })
  test('should convert incoming JSON to MIDI files', async () => {
    const execResult = await exec('cat test/data/midi-timemap.test.mid | node src/js/midi-file.js | node src/js/midi-file.js', { encoding: 'buffer' })
    const original = fs.readFileSync('test/data/midi-timemap.test.mid')
    expect(execResult.stdout).toEqual(original)
  })
})
