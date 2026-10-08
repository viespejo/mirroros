export class PlanContractError extends Error {
  constructor(errors) {
    super(Array.isArray(errors) ? errors.join('\n') : String(errors));
    this.name = 'PlanContractError';
    this.errors = Array.isArray(errors) ? errors : [String(errors)];
  }
}

function compareCodePoints(left, right) {
  const a = Array.from(left);
  const b = Array.from(right);
  const length = Math.min(a.length, b.length);
  for (let index = 0; index < length; index += 1) {
    const difference = a[index].codePointAt(0) - b[index].codePointAt(0);
    if (difference !== 0) return difference;
  }
  return a.length - b.length;
}

function serialize(value, path) {
  if (value === null) return 'null';
  switch (typeof value) {
    case 'boolean':
      return value ? 'true' : 'false';
    case 'string':
      return JSON.stringify(value);
    case 'number':
      if (!Number.isSafeInteger(value)) {
        throw new PlanContractError(`${path} is not a canonical integer`);
      }
      return String(value);
    case 'object': {
      if (Array.isArray(value)) {
        return `[${value.map((item, index) => serialize(item, `${path}[${index}]`)).join(',')}]`;
      }
      const prototype = Object.getPrototypeOf(value);
      if (prototype !== Object.prototype && prototype !== null) {
        throw new PlanContractError(`${path} is not a plain JSON object`);
      }
      const members = Object.keys(value)
        .sort(compareCodePoints)
        .map(key => `${JSON.stringify(key)}:${serialize(value[key], `${path}.${key}`)}`);
      return `{${members.join(',')}}`;
    }
    default:
      throw new PlanContractError(`${path} has a type that cannot be canonicalized (${typeof value})`);
  }
}

export function canonicalize(value) {
  return serialize(value, '$');
}
