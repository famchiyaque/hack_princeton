// Kinetic web prototype — captures webcam, streams JPEG frames to the
// Python backend over WebSocket, renders the returned skeleton + HUD.

const SEND_FPS = 12;             // how often we ship a frame to the server
const JPEG_QUALITY = 0.55;
const SEND_WIDTH = 480;          // downscaled before transmit

// Bones drawn on the overlay (names match pose.py).
const BONES = [
  ["leftShoulder", "rightShoulder"],
  ["leftShoulder", "leftElbow"], ["leftElbow", "leftWrist"],
  ["rightShoulder", "rightElbow"], ["rightElbow", "rightWrist"],
  ["leftShoulder", "leftHip"], ["rightShoulder", "rightHip"],
  ["leftHip", "rightHip"],
  ["leftHip", "leftKnee"], ["leftKnee", "leftAnkle"],
  ["rightHip", "rightKnee"], ["rightKnee", "rightAnkle"],
];

const video = document.getElementById("cam");
const overlay = document.getElementById("overlay");
const ctx = overlay.getContext("2d");
const liveView = document.getElementById("live-view");
const reportView = document.getElementById("report-view");
const exerciseLabel = document.getElementById("exercise-label");
const phaseLabel = document.getElementById("phase-label");
const repCountEl = document.getElementById("rep-count");
const scoreEl = document.getElementById("score");
const correctionEl = document.getElementById("correction");
const statusEl = document.getElementById("status");
const endBtn = document.getElementById("end-btn");
const againBtn = document.getElementById("again-btn");

let ws = null;
let sending = false;          // backpressure: skip frame if previous in flight
let sendCanvas = null;
let sendCtx = null;
let latestFrame = null;       // latest server response for overlay draw
let correctionTimer = 0;
let ended = false;

function setStatus(text) { statusEl.textContent = text; }

async function startCamera() {
  const stream = await navigator.mediaDevices.getUserMedia({
    video: { width: 1280, height: 720, facingMode: "user" },
    audio: false,
  });
  video.srcObject = stream;
  await new Promise(res => video.onloadedmetadata = res);
  await video.play();

  overlay.width = video.videoWidth;
  overlay.height = video.videoHeight;

  const scale = SEND_WIDTH / video.videoWidth;
  sendCanvas = document.createElement("canvas");
  sendCanvas.width = SEND_WIDTH;
  sendCanvas.height = Math.round(video.videoHeight * scale);
  sendCtx = sendCanvas.getContext("2d");
}

function connect() {
  const proto = location.protocol === "https:" ? "wss:" : "ws:";
  ws = new WebSocket(`${proto}//${location.host}/ws/session`);
  ws.binaryType = "arraybuffer";

  ws.onopen = () => { setStatus("live"); startSendLoop(); };
  ws.onclose = () => setStatus("disconnected");
  ws.onerror = () => setStatus("error");
  ws.onmessage = (ev) => {
    const msg = JSON.parse(ev.data);
    if (msg.type === "frame") {
      latestFrame = msg;
      sending = false;
      updateHud(msg);
    } else if (msg.type === "report") {
      showReport(msg.report);
    }
  };
}

function startSendLoop() {
  const interval = 1000 / SEND_FPS;
  setInterval(() => {
    if (ended || !ws || ws.readyState !== 1 || sending) return;
    if (!video.videoWidth) return;
    sendCtx.drawImage(video, 0, 0, sendCanvas.width, sendCanvas.height);
    sendCanvas.toBlob(async (blob) => {
      if (!blob || ws.readyState !== 1) return;
      sending = true;
      ws.send(await blob.arrayBuffer());
    }, "image/jpeg", JPEG_QUALITY);
  }, interval);
}

function updateHud(msg) {
  exerciseLabel.textContent = msg.exerciseDisplay || "Detecting…";
  phaseLabel.textContent = msg.phase || "—";
  repCountEl.textContent = msg.repCount ?? 0;
  scoreEl.textContent = (msg.score != null && msg.score > 0) ? Math.round(msg.score) : "—";

  if (msg.corrections && msg.corrections.length > 0 && msg.corrections[0].severity > 0.3) {
    correctionEl.textContent = msg.corrections[0].message;
    correctionEl.classList.add("visible");
    correctionTimer = 30;
  } else if (correctionTimer > 0) {
    correctionTimer--;
    if (correctionTimer === 0) correctionEl.classList.remove("visible");
  }
  drawSkeleton(msg.landmarks || {});
}

function drawSkeleton(landmarks) {
  ctx.clearRect(0, 0, overlay.width, overlay.height);
  const W = overlay.width, H = overlay.height;

  ctx.strokeStyle = "#ff7a3c";
  ctx.lineWidth = 4;
  ctx.lineCap = "round";

  for (const [a, b] of BONES) {
    const pa = landmarks[a], pb = landmarks[b];
    if (!pa || !pb) continue;
    ctx.beginPath();
    ctx.moveTo(pa.x * W, pa.y * H);
    ctx.lineTo(pb.x * W, pb.y * H);
    ctx.stroke();
  }

  ctx.fillStyle = "#fff";
  for (const name in landmarks) {
    const p = landmarks[name];
    ctx.beginPath();
    ctx.arc(p.x * W, p.y * H, 5, 0, Math.PI * 2);
    ctx.fill();
  }
}

function showReport(r) {
  ended = true;
  liveView.hidden = true;
  reportView.hidden = false;

  document.getElementById("r-exercise").textContent = r.exercise + " Report";
  document.getElementById("r-reps").textContent = r.reps;
  document.getElementById("r-score").textContent = Math.round(r.avgScore);
  document.getElementById("r-consistency").textContent = Math.round(r.consistency);
  document.getElementById("r-duration").textContent = `${r.duration}s`;

  const strengthsUl = document.getElementById("r-strengths");
  strengthsUl.innerHTML = "";
  r.strengths.forEach(s => { const li = document.createElement("li"); li.textContent = s; strengthsUl.appendChild(li); });

  const risksUl = document.getElementById("r-risks");
  risksUl.innerHTML = "";
  r.risks.forEach(s => { const li = document.createElement("li"); li.textContent = s; risksUl.appendChild(li); });

  const t = r.tempo;
  document.getElementById("r-tempo").textContent =
    `${t.label} — avg ${t.avg_rep_seconds.toFixed(1)}s / rep (fastest ${t.fastest.toFixed(1)}s, slowest ${t.slowest.toFixed(1)}s)`;

  const bars = document.getElementById("r-bars");
  bars.innerHTML = "";
  r.perRepScores.forEach(s => {
    const bar = document.createElement("div");
    bar.className = "bar";
    bar.style.height = `${Math.max(4, s)}%`;
    bar.title = `${Math.round(s)}/100`;
    bars.appendChild(bar);
  });
}

endBtn.addEventListener("click", () => {
  if (ws && ws.readyState === 1) {
    ws.send(JSON.stringify({ type: "end" }));
  }
});

againBtn.addEventListener("click", () => {
  location.reload();
});

(async () => {
  try {
    await startCamera();
    connect();
  } catch (e) {
    setStatus(`camera error: ${e.message}`);
    console.error(e);
  }
})();
