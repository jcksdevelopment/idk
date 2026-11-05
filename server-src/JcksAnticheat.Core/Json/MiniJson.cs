using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.Text;

namespace JcksAnticheat.Core.Json
{
    public static class MiniJson
    {
        public const int MaxDepth = 32;

        public static object? Parse(string json, int maxLength = 1 << 20)
        {
            if (json == null) throw new FormatException("null input");
            if (json.Length > maxLength) throw new FormatException("input too large");
            var p = new Parser(json);
            p.SkipWs();
            var v = p.ReadValue(0);
            p.SkipWs();
            if (!p.End) throw new FormatException("trailing characters at " + p.Pos);
            return v;
        }

        public static bool TryParse(string json, out object? value, int maxLength = 1 << 20)
        {
            try { value = Parse(json, maxLength); return true; }
            catch (FormatException) { value = null; return false; }
        }

        public static string Serialize(object? value)
        {
            var sb = new StringBuilder(128);
            Write(sb, value, 0);
            return sb.ToString();
        }

        private static void Write(StringBuilder sb, object? v, int depth)
        {
            if (depth > MaxDepth) throw new InvalidOperationException("max depth");
            switch (v)
            {
                case null: sb.Append("null"); break;
                case string s: WriteString(sb, s); break;
                case bool b: sb.Append(b ? "true" : "false"); break;
                case double d: sb.Append(FormatNumber(d)); break;
                case float f: sb.Append(FormatNumber(f)); break;
                case int i: sb.Append(i.ToString(CultureInfo.InvariantCulture)); break;
                case long l: sb.Append(l.ToString(CultureInfo.InvariantCulture)); break;
                case uint ui: sb.Append(ui.ToString(CultureInfo.InvariantCulture)); break;
                case DateTime dt: WriteString(sb, dt.ToUniversalTime().ToString("o", CultureInfo.InvariantCulture)); break;
                case IJsonWritable w: Write(sb, w.ToJson(), depth); break;
                case IDictionary dict:
                    sb.Append('{');
                    bool first = true;
                    foreach (DictionaryEntry e in dict)
                    {
                        if (!first) sb.Append(',');
                        first = false;
                        WriteString(sb, Convert.ToString(e.Key, CultureInfo.InvariantCulture) ?? "");
                        sb.Append(':');
                        Write(sb, e.Value, depth + 1);
                    }
                    sb.Append('}');
                    break;
                case IEnumerable list:
                    sb.Append('[');
                    bool firstItem = true;
                    foreach (var item in list)
                    {
                        if (!firstItem) sb.Append(',');
                        firstItem = false;
                        Write(sb, item, depth + 1);
                    }
                    sb.Append(']');
                    break;
                default:
                    if (v is IConvertible c) sb.Append(FormatNumber(c.ToDouble(CultureInfo.InvariantCulture)));
                    else WriteString(sb, v.ToString() ?? "");
                    break;
            }
        }

        private static string FormatNumber(double d)
        {
            if (double.IsNaN(d) || double.IsInfinity(d)) return "null";
            if (Math.Abs(d % 1) < double.Epsilon && Math.Abs(d) < 1e15) return ((long)d).ToString(CultureInfo.InvariantCulture);
            return d.ToString("R", CultureInfo.InvariantCulture);
        }

        private static void WriteString(StringBuilder sb, string s)
        {
            sb.Append('"');
            foreach (var ch in s)
            {
                switch (ch)
                {
                    case '"': sb.Append("\\\""); break;
                    case '\\': sb.Append("\\\\"); break;
                    case '\n': sb.Append("\\n"); break;
                    case '\r': sb.Append("\\r"); break;
                    case '\t': sb.Append("\\t"); break;
                    case '\b': sb.Append("\\b"); break;
                    case '\f': sb.Append("\\f"); break;
                    default:
                        if (ch < 0x20) sb.Append("\\u").Append(((int)ch).ToString("x4"));
                        else sb.Append(ch);
                        break;
                }
            }
            sb.Append('"');
        }

        private sealed class Parser
        {
            private readonly string _s;
            public int Pos;
            public Parser(string s) { _s = s; }
            public bool End => Pos >= _s.Length;

            public void SkipWs()
            {
                while (Pos < _s.Length && (_s[Pos] == ' ' || _s[Pos] == '\t' || _s[Pos] == '\n' || _s[Pos] == '\r')) Pos++;
            }

            private char Peek() => Pos < _s.Length ? _s[Pos] : '\0';

            private void Expect(char c)
            {
                if (Peek() != c) throw new FormatException($"expected '{c}' at {Pos}");
                Pos++;
            }

            public object? ReadValue(int depth)
            {
                if (depth > MaxDepth) throw new FormatException("max depth");
                switch (Peek())
                {
                    case '{': return ReadObject(depth);
                    case '[': return ReadArray(depth);
                    case '"': return ReadString();
                    case 't': ReadLiteral("true"); return true;
                    case 'f': ReadLiteral("false"); return false;
                    case 'n': ReadLiteral("null"); return null;
                    default: return ReadNumber();
                }
            }

            private void ReadLiteral(string lit)
            {
                if (string.CompareOrdinal(_s, Pos, lit, 0, lit.Length) != 0) throw new FormatException("bad literal at " + Pos);
                Pos += lit.Length;
            }

            private Dictionary<string, object?> ReadObject(int depth)
            {
                Expect('{');
                var d = new Dictionary<string, object?>(StringComparer.Ordinal);
                SkipWs();
                if (Peek() == '}') { Pos++; return d; }
                while (true)
                {
                    SkipWs();
                    var key = ReadString();
                    SkipWs();
                    Expect(':');
                    SkipWs();
                    d[key] = ReadValue(depth + 1);
                    SkipWs();
                    if (Peek() == ',') { Pos++; continue; }
                    Expect('}');
                    return d;
                }
            }

            private List<object?> ReadArray(int depth)
            {
                Expect('[');
                var l = new List<object?>();
                SkipWs();
                if (Peek() == ']') { Pos++; return l; }
                while (true)
                {
                    SkipWs();
                    l.Add(ReadValue(depth + 1));
                    SkipWs();
                    if (Peek() == ',') { Pos++; continue; }
                    Expect(']');
                    return l;
                }
            }

            private string ReadString()
            {
                Expect('"');
                var sb = new StringBuilder();
                while (true)
                {
                    if (End) throw new FormatException("unterminated string");
                    char c = _s[Pos++];
                    if (c == '"') return sb.ToString();
                    if (c != '\\') { sb.Append(c); continue; }
                    if (End) throw new FormatException("bad escape");
                    char e = _s[Pos++];
                    switch (e)
                    {
                        case '"': sb.Append('"'); break;
                        case '\\': sb.Append('\\'); break;
                        case '/': sb.Append('/'); break;
                        case 'b': sb.Append('\b'); break;
                        case 'f': sb.Append('\f'); break;
                        case 'n': sb.Append('\n'); break;
                        case 'r': sb.Append('\r'); break;
                        case 't': sb.Append('\t'); break;
                        case 'u':
                            if (Pos + 4 > _s.Length) throw new FormatException("bad unicode escape");
                            sb.Append((char)int.Parse(_s.Substring(Pos, 4), NumberStyles.HexNumber, CultureInfo.InvariantCulture));
                            Pos += 4;
                            break;
                        default: throw new FormatException("bad escape");
                    }
                }
            }

            private double ReadNumber()
            {
                int start = Pos;
                while (Pos < _s.Length && "+-0123456789.eE".IndexOf(_s[Pos]) >= 0) Pos++;
                if (start == Pos) throw new FormatException("unexpected character at " + Pos);
                if (!double.TryParse(_s.Substring(start, Pos - start), NumberStyles.Float, CultureInfo.InvariantCulture, out var d))
                    throw new FormatException("bad number at " + start);
                return d;
            }
        }
    }

    public interface IJsonWritable
    {
        object ToJson();
    }

    public static class JsonAccess
    {
        public static Dictionary<string, object?>? Obj(this object? o, string key) =>
            (o as Dictionary<string, object?>) is { } d && d.TryGetValue(key, out var v) ? v as Dictionary<string, object?> : null;

        public static List<object?>? Arr(this object? o, string key) =>
            (o as Dictionary<string, object?>) is { } d && d.TryGetValue(key, out var v) ? v as List<object?> : null;

        public static double? Num(this object? o, string key) =>
            (o as Dictionary<string, object?>) is { } d && d.TryGetValue(key, out var v) && v is double n ? n : (double?)null;

        public static string? Str(this object? o, string key) =>
            (o as Dictionary<string, object?>) is { } d && d.TryGetValue(key, out var v) ? v as string : null;

        public static bool? Bool(this object? o, string key) =>
            (o as Dictionary<string, object?>) is { } d && d.TryGetValue(key, out var v) && v is bool b ? b : (bool?)null;
    }
}
