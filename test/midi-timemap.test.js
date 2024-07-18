import util from 'util'
import { createRequire } from 'module'
const require = createRequire(import.meta.url)
const exec = util.promisify(require('child_process').exec)

describe('MIDI to timemap conversion cli', () => {
  test('should run successfully', async () => {
    const execResult = await exec('node src/js/midi-timemap test/data/midi-timemap.test.mid')
    const timemap = JSON.parse(execResult.stdout);
    expect(timemap[timemap.length-1].timestamp).toEqual(116800)
    expect(timemap[timemap.length-1].duration).toEqual(1600)
  })
})
