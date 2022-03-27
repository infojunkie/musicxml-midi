import request from 'supertest'
import { app, server } from '../server'

describe('MusicXML to MIDI conversion server', () => {
  test('should retrieve version information', async () => {
    const res = await request(app).get('/')
    expect(res.statusCode).toEqual(200)
    expect(res.body).toHaveProperty('name')
  })
})

afterAll(() => {
  server.close();
});
