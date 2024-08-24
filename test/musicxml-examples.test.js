import util from 'util'
import { createRequire } from 'module'
import e from 'express'
const require = createRequire(import.meta.url)
const exec = util.promisify(require('child_process').exec)

describe('MusicXML examples scraper', () => {
  test('should run successfully', async () => {
    const execResult = await exec('node src/js/musicxml-examples.js --examples=accordion-high-element,accordion-low-element')
    const output = execResult.stdout;
    expect(output).toMatch(/accordion-high/)
    expect(output).not.toMatch(/accidental-element/)
  })
})
