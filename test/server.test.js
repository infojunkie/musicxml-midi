import sinon from 'sinon'
import request from 'supertest'
import fs from 'fs'
import crypto from 'crypto'
import path from 'path'
import { parseMidi } from 'midi-file'
import { app, server } from '../server'
import SaxonJS from 'saxon-js'

describe('MusicXML to MIDI conversion server', () => {
  test('should retrieve version information', async () => {
    const res = await request(app).get('/')
    expect(res.statusCode).toEqual(200)
    expect(res.body).toHaveProperty('name')
  })

  test('should reject invalid invocations', async () => {
    const res1 = await request(app).get('/convert')
    expect(res1.statusCode).toEqual(400)
    const res2 = await request(app).post('/convert').field('foo', 'bar')
    expect(res2.statusCode).toEqual(400)
    const res3 = await request(app).post('/convert').attach('musicxml', 'package.json')
    expect(res3.statusCode).toEqual(400)
    const res4 = await request(app).post('/convert').attach('musicxml', 'test/data/large-file.png')
    expect(res4.statusCode).toEqual(413)
  })

  test('should convert valid MusicXML files', async () => {
    const res = await request(app).post('/convert').attach('musicxml', 'test/data/take-five.musicxml').responseType('blob')
    expect(res.statusCode).toEqual(200)
    expect(res.type).toEqual('audio/midi')
    expect(() => {
      const midi = parseMidi(res.body)
    }).not.toThrow()
  })

  test('should cache valid MusicXML files and use the cache', async () => {
    const file = 'test/data/take-five.musicxml'
    const params = {}
    const buffer = fs.readFileSync(file)
    const hash = crypto.createHash('sha256')
    hash.update(buffer + JSON.stringify(params))
    const sig = hash.digest('hex')
    const cacheFile = path.resolve(path.join(process.env.CACHE_DIR || 'cache', `${sig}.mid`))
    fs.unlinkSync(cacheFile)
    expect(fs.existsSync(cacheFile)).not.toBeTruthy()
    await request(app).post('/convert').attach('musicxml', file)
    expect(fs.existsSync(cacheFile)).toBeTruthy()
    const transform = sinon.spy(SaxonJS, 'transform')
    await request(app).post('/convert').attach('musicxml', file)
    sinon.assert.neverCalledWith(transform)
  })

  test('should pass parameters to the converter', async () => {
    const res = await request(app)
      .post('/convert')
      .field('globalGroove', 'Maqsum')
      .attach('musicxml', 'test/data/salma-ya-salama.musicxml')
      .responseType('blob')
    expect(parseMidi(res.body).tracks.find(track => !!track.find(event => event.type === 'marker' && event.text === 'Groove:Maqsum')))
      .not.toEqual(undefined)
  })

  test('should get existing grooves', async () => {
    const res = await request(app).get('/grooves')
    expect(res.statusCode).toEqual(200)
    expect(res.text).toEqual(fs.readFileSync('grooves.txt').toString())
  })

  test('should use SaxonJS to perform XPath queries', async () => {
    const doc = await SaxonJS.getResource({
      'file': 'test/data/salma-ya-salama.musicxml',
      'type': 'xml',
      'encoding': 'utf8'
    })
    expect(SaxonJS.XPath.evaluate('//work/work-title/text()', doc).nodeValue).toEqual('Salma ya salama سالمة يا سلامة')
  })
})

afterAll(() => {
  server.close()
})
