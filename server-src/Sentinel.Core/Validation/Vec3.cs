using System;

namespace Sentinel.Core.Validation
{
    /// <summary>Minimal vector type so the core library has no CitizenFX dependency.</summary>
    public readonly struct Vec3
    {
        public Vec3(float x, float y, float z) { X = x; Y = y; Z = z; }
        public float X { get; }
        public float Y { get; }
        public float Z { get; }

        public static Vec3 operator -(Vec3 a, Vec3 b) => new Vec3(a.X - b.X, a.Y - b.Y, a.Z - b.Z);
        public float Length => (float)Math.Sqrt(X * X + Y * Y + Z * Z);
        public float Length2D => (float)Math.Sqrt(X * X + Y * Y);
        public static float Distance(Vec3 a, Vec3 b) => (a - b).Length;
        public static float Dot(Vec3 a, Vec3 b) => a.X * b.X + a.Y * b.Y + a.Z * b.Z;

        public Vec3 Normalized()
        {
            var l = Length;
            return l < 1e-6f ? new Vec3(0, 0, 0) : new Vec3(X / l, Y / l, Z / l);
        }

        /// <summary>Forward unit vector on the XY plane for a GTA heading (degrees, 0 = north/+Y, counter-clockwise).</summary>
        public static Vec3 FromHeading(float headingDegrees)
        {
            double r = headingDegrees * Math.PI / 180.0;
            return new Vec3((float)-Math.Sin(r), (float)Math.Cos(r), 0);
        }

        /// <summary>Angle in degrees between two vectors (XY plane only).</summary>
        public static float Angle2D(Vec3 a, Vec3 b)
        {
            var la = a.Length2D; var lb = b.Length2D;
            if (la < 1e-6f || lb < 1e-6f) return 0;
            double cos = (a.X * b.X + a.Y * b.Y) / (la * lb);
            cos = Math.Max(-1.0, Math.Min(1.0, cos));
            return (float)(Math.Acos(cos) * 180.0 / Math.PI);
        }

        public override string ToString() => $"({X:F1}, {Y:F1}, {Z:F1})";
    }
}
