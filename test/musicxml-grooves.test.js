import util from 'util'
import { createRequire } from 'module'
const require = createRequire(import.meta.url)
const exec = util.promisify(require('child_process').exec)

describe('MusicXML grooves converter', () => {
  test('should run successfully', async () => {
    const execResult = await exec('node src/js/musicxml-grooves.js --validate --grooves=JazzBasieA,JazzWaltzMainA')
    const output = execResult.stderr
    expect(output).toMatch(/Generating Jazz(BasieA|WaltzMainA)\.\.\.[\n]Generating Jazz(WaltzMainA|BasieA)\.\.\.[\n]/g)
  })
})
