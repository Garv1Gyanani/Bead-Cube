import React, { useEffect, useRef, useState } from 'react';

const COLORS = {
  blue: '#2B83F6',
  red: '#EE4B4B',
  yellow: '#F5C525',
  cyan: '#17B9D9',
  green: '#22C55E',
};

const BEADS = {
  front: { 5: 'blue', 6: 'blue', 9: 'blue', 10: 'blue', 1: 'cyan', 2: 'red', 3: 'red' },
  top: { 13: 'cyan', 9: 'cyan', 14: 'yellow', 10: 'yellow' },
  right: { 0: 'red', 4: 'red', 8: 'green', 9: 'green', 13: 'green' },
  left: { 6: 'cyan', 7: 'cyan', 11: 'cyan' },
  back: { 5: 'yellow', 6: 'yellow' },
  bottom: { 5: 'green', 6: 'green' },
};

const FACES = ['front', 'back', 'right', 'left', 'top', 'bottom'];

export default function InteractiveCubeShowcase() {
  const [rotation, setRotation] = useState({ x: -24, y: -32 });
  const dragRef = useRef(null);

  useEffect(() => {
    let rafId;
    const tick = () => {
      if (!dragRef.current) {
        setRotation((r) => ({ x: r.x, y: r.y + 0.16 }));
      }
      rafId = requestAnimationFrame(tick);
    };
    rafId = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(rafId);
  }, []);

  const handlePointerDown = (e) => {
    dragRef.current = {
      startX: e.clientX,
      startY: e.clientY,
      baseX: rotation.x,
      baseY: rotation.y,
    };
  };

  const handlePointerMove = (e) => {
    if (!dragRef.current) return;
    const dx = e.clientX - dragRef.current.startX;
    const dy = e.clientY - dragRef.current.startY;
    setRotation({
      x: Math.max(-60, Math.min(60, dragRef.current.baseX - dy * 0.45)),
      y: dragRef.current.baseY + dx * 0.55,
    });
  };

  const handlePointerUp = () => {
    dragRef.current = null;
  };

  return (
    <div className="hero-cube-wrap">
      <div
        className="cube-stage"
        onPointerDown={handlePointerDown}
        onPointerMove={handlePointerMove}
        onPointerUp={handlePointerUp}
        onPointerLeave={handlePointerUp}
      >
        <div
          className="cube-3d"
          style={{
            transform: `rotateX(${rotation.x}deg) rotateY(${rotation.y}deg)`,
          }}
        >
          {FACES.map((face) => {
            const faceMap = BEADS[face] || {};
            return (
              <div key={face} className={`cube-face ${face}`}>
                {Array.from({ length: 16 }).map((_, slotIdx) => {
                  const colorKey = faceMap[slotIdx];
                  const hex = colorKey ? COLORS[colorKey] : undefined;
                  return (
                    <div
                      key={slotIdx}
                      className={`bead-slot ${hex ? 'filled' : ''}`}
                      style={hex ? { background: hex } : undefined}
                    />
                  );
                })}
              </div>
            );
          })}
        </div>
      </div>
      <span className="cube-hint">Drag to rotate</span>
    </div>
  );
}
