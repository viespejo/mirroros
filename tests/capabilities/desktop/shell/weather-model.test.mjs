// Weather model: the cases of Omarchy v4.5.0 test/shell.d/weather-test.sh (MIT,
// Copyright (c) David Heinemeier Hansson) that still apply to the adapted
// panels/weather/Model.js, ported to node:test. The wttr.in, weather.json, IP
// auto-detection and omarchy-weather-location cases are dropped with the code
// they covered (ADR 0029); the request builders added by MirrorOS follow.
import test from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const weather = require('../../../../capabilities/desktop/shell/panels/weather/Model.js');

const assertEqual = (actual, expected, description) => assert.equal(actual, expected, description);
// Upstream compares deep values through JSON, so the port does too.
const assertDeepEqual = (actual, expected, description) =>
  assert.equal(JSON.stringify(actual), JSON.stringify(expected), description);
const check = (condition, description) => assert.ok(condition, description);

test('location commit', () => {
  assertDeepEqual(weather.locationCommit('  Pasadena  ', [], 0), { name: 'Pasadena', latitude: null, longitude: null }, 'weather commits typed locations before suggestions load');
  assertDeepEqual(weather.locationCommit('', [], 0), { name: '', latitude: null, longitude: null }, 'weather commits an empty location as unset');
  assertDeepEqual(
    weather.locationCommit('mal', [{ name: 'Malibu', latitude: 34.02577, longitude: -118.7804 }], 0),
    { name: 'Malibu', latitude: 34.02577, longitude: -118.7804 },
    'weather commits the selected geocoding suggestion when available'
  );
});

test('geocoding results', () => {
  assertDeepEqual(
    weather.parseGeocodingResults(JSON.stringify({
      results: [
        { name: 'Malibu', latitude: 34.02577, longitude: -118.7804, admin1: 'California', country: 'United States' },
        { name: 'Malibu', latitude: -7.18333, longitude: 29.65, admin1: 'Tanganyika', country: 'Democratic Republic of Congo' },
        { name: 'Broken', latitude: 1.0 },
        { name: 'Bare', latitude: 2.0, longitude: 3.0 }
      ]
    })),
    [
      { name: 'Malibu', description: 'California, United States', latitude: 34.02577, longitude: -118.7804 },
      { name: 'Malibu', description: 'Tanganyika, Democratic Republic of Congo', latitude: -7.18333, longitude: 29.65 },
      { name: 'Bare', description: '', latitude: 2.0, longitude: 3.0 }
    ],
    'weather parses geocoding suggestions and drops incomplete rows'
  );
  assertDeepEqual(weather.parseGeocodingResults('{}'), [], 'weather handles empty geocoding responses');
  assertDeepEqual(weather.parseGeocodingResults('{'), [], 'weather handles invalid geocoding JSON');
});

test('temperatures, units and day names', () => {
  assertEqual(weather.roundedTemp('21.6'), '22', 'weather rounds temperatures');
  assertEqual(weather.roundedTemp('nope'), '', 'weather ignores invalid temperatures');
  assertEqual(weather.formatTemp(72, true), '72°F', 'weather formats imperial temperatures');
  assertEqual(weather.formatTemp(22, false), '22°C', 'weather formats metric temperatures');
  assertEqual(weather.shouldUseImperial('', 'en_US', ''), true, 'weather falls back to US locale for imperial units');
  assertEqual(weather.shouldUseImperial('', 'en_US', 'Denmark'), false, 'weather prefers reported metric country over US locale');
  assertEqual(weather.shouldUseImperial('', 'da_DK', 'United States of America'), true, 'weather prefers reported imperial country over metric locale');
  assertEqual(weather.shouldUseImperial('metric', 'en_US', 'United States of America'), false, 'weather metric override wins');
  assertEqual(weather.shouldUseImperial('imperial', 'da_DK', 'Denmark'), true, 'weather imperial override wins');
  assertEqual(weather.dayName('2026-05-25'), 'Monday', 'weather derives day names');
});

test('open-meteo forecast and current conditions', () => {
  const openMeteo = {
    daily: {
      time: ['2026-05-25', '2026-05-26', '2026-05-27', '2026-05-28', '2026-05-29'],
      temperature_2m_max: [20.1, 21.6, 18.2, 17.9, 22.4],
      temperature_2m_min: [12.2, 13.1, 10.8, 9.2, 11.5],
      weather_code: [0, 63, 95, 3, 1]
    }
  };

  assertDeepEqual(
    weather.openMeteoForecastDays(openMeteo, '2026-05-25').map(day => ({
      date: day.date,
      maxtempC: day.maxtempC,
      mintempF: day.mintempF,
      code: day.openMeteoWeatherCode
    })),
    [
      { date: '2026-05-26', maxtempC: '22', mintempF: '56', code: 63 },
      { date: '2026-05-27', maxtempC: '18', mintempF: '51', code: 95 },
      { date: '2026-05-28', maxtempC: '18', mintempF: '49', code: 3 }
    ],
    'weather builds future Open-Meteo forecast days'
  );

  assertDeepEqual(
    weather.openMeteoCurrentCondition({ current: { temperature_2m: 21.4, apparent_temperature: 19.8, wind_speed_10m: 14.3, relative_humidity_2m: 63 } }),
    { temp_C: '21', temp_F: '71', FeelsLikeC: '20', FeelsLikeF: '68', windspeedKmph: '14', windspeedMiles: '9', humidity: '63' },
    'weather normalizes open-meteo current conditions to the wttr shape'
  );
  assertEqual(weather.openMeteoCurrentCondition({}), null, 'weather returns no current conditions without open-meteo data');
  assertEqual(weather.openMeteoCurrentCondition({ current: {} }), null, 'weather requires a current temperature');

  assertEqual(weather.bareTempForDay({ maxtempC: '22', mintempC: '13', maxtempF: '72', mintempF: '55' }, 'max', false), '22°', 'weather formats forecast metric highs');
  assertEqual(weather.bareTempForDay({ maxtempC: '22', mintempC: '13', maxtempF: '72', mintempF: '55' }, 'min', true), '55°', 'weather formats forecast imperial lows');
});

test('icons', () => {
  check(weather.dayIcon({ openMeteoWeatherCode: 95 }).length > 0, 'weather maps Open-Meteo weather icons');
  assertEqual(weather.currentIcon({ openMeteoWeatherCode: 0, isDay: 1 }, ''), weather.iconForOpenMeteoCode(0), 'weather uses the current Open-Meteo icon with current values');
  assertEqual(weather.currentIcon({ openMeteoWeatherCode: 0, isDay: 0 }, ''), weather.iconForCode(113, true), 'weather uses the nighttime Open-Meteo icon after sunset');
  check(weather.iconForOpenMeteoCode(45, true) !== weather.iconForOpenMeteoCode(45, false), 'weather distinguishes nighttime fog from daytime fog');
  assertEqual(
    weather.dayIcon({ hourly: [{ time: '900', weatherCode: 113 }, { time: '1200', weatherCode: 389 }, { time: '1800', weatherCode: 116 }] }),
    weather.iconForCode(389, false),
    'weather picks hourly forecast icon nearest noon'
  );
});

test('the wttr.in, location-file and IP auto-detection functions are gone', () => {
  for (const name of ['parseLocationFile', 'isAutoLocation', 'effectiveLocation', 'wttrLocationQuery',
    'provisionalCurrentIcon', 'weatherResponseCompletesSave', 'wttrNextForecastDays', 'buildForecastDays'])
    assert.equal(weather[name], undefined, name);
});

test('requests use fixed https:// open-meteo URLs through curl argv', () => {
  const malibu = { name: 'Malibu', latitude: 34.02577, longitude: -118.7804 };
  const oslo = { name: 'Oslo', latitude: 59.91273, longitude: 10.74609 };
  const fields = '&daily=weather_code,temperature_2m_max,temperature_2m_min'
    + '&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day'
    + '&forecast_days=4&timezone=auto';

  assert.deepEqual(weather.forecastCommand([malibu]), ['curl', '-fsS', '--max-time', '5',
    'https://api.open-meteo.com/v1/forecast?latitude=34.02577&longitude=-118.7804' + fields]);
  assert.deepEqual(weather.forecastCommand([malibu, oslo]), ['curl', '-fsS', '--max-time', '5',
    'https://api.open-meteo.com/v1/forecast?latitude=34.02577,59.91273&longitude=-118.7804,10.74609' + fields],
  'one combined request for several locations');
  assert.deepEqual(weather.forecastCommand([]), [], 'no request without a location');
  assert.deepEqual(weather.forecastCommand([{ name: 'x', latitude: 'nope', longitude: 1 }]), [],
    'no request with an unreadable coordinate');

  assert.deepEqual(weather.geocodingCommand('São Paulo&x=1'), ['curl', '-fsS', '--max-time', '5',
    'https://geocoding-api.open-meteo.com/v1/search?name=S%C3%A3o%20Paulo%26x%3D1&count=5&language=en&format=json'],
  'the typed text is URL-encoded into the fixed geocoder URL');
});

test('forecast answers are read as one report per requested location', () => {
  const one = { current: { temperature_2m: 1 } };
  const two = { current: { temperature_2m: 2 } };
  assertDeepEqual(weather.parseForecastReports(JSON.stringify(one), 1), [one], 'a single-location answer is one object');
  assertDeepEqual(weather.parseForecastReports(JSON.stringify([one, two]), 2), [one, two], 'a combined answer is an array');
  assertEqual(weather.parseForecastReports(JSON.stringify([one]), 2), null, 'a short answer is rejected');
  assertEqual(weather.parseForecastReports('', 1), null, 'an empty answer (failed curl) is rejected');
  assertEqual(weather.parseForecastReports('{', 1), null, 'invalid JSON is rejected');
});

test('the empty pill glyph is a neutral weather glyph', () => {
  assertEqual(weather.NEUTRAL_ICON, '\ue350');
});
