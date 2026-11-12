import React, { useMemo, useState } from 'react';
import { ArrowLeft, Check, ChevronRight, CloudOff, MessageCircle, Plus, Ruler, Scissors, Wallet } from 'lucide-react';
import { FitArea, GroupOrder, Guest, STAGES, Stage, TEMPLATES, daysTo, naira, paidOf } from './data';

const STAGE_TONE: Record<Stage, string> = {
  'Not measured': 'bg-stone-200 text-stone-700', Measured: 'bg-sky-100 text-sky-800', Cutting: 'bg-amber-100 text-amber-800',
  Sewing: 'bg-orange-100 text-orange-800', 'Ready for fitting': 'bg-violet-100 text-violet-800', Fitted: 'bg-emerald-100 text-emerald-800', Collected: 'bg-emerald-600 text-white',
};
const Pill: React.FC<{ s: Stage }> = ({ s }) => <span className={`rounded-full px-2 py-0.5 text-[11px] font-bold ${STAGE_TONE[s]}`}>{s}</span>;

export const TailorApp: React.FC<{ order: GroupOrder; setOrder: (o: GroupOrder) => void; offline: boolean }> = ({ order, setOrder, offline }) => {
  const [guestId, setGuestId] = useState<string | null>(null);
  const [filter, setFilter] = useState<Stage | 'All' | 'Owing'>('All');
  const [adding, setAdding] = useState(false);
  const guest = order.guests.find(x => x.id === guestId) || null;
  const update = (g: Guest) => setOrder({ ...order, guests: order.guests.map(x => (x.id === g.id ? g : x)) });

  return (
    <div className="flex h-full flex-col">
      {offline && <div className="flex items-center gap-2 bg-amber-100 px-4 py-1.5 text-[11px] font-semibold text-amber-900"><CloudOff className="h-3.5 w-3.5" /> Offline: changes are saved on this phone and sync later</div>}
      {guest ? <GuestScreen g={guest} onBack={() => setGuestId(null)} onChange={update} />
        : <Board order={order} filter={filter} setFilter={setFilter} open={setGuestId} onAdd={() => setAdding(true)} />}
      {adding && <AddGuest onClose={() => setAdding(false)} onAdd={g => { setOrder({ ...order, guests: [...order.guests, g] }); setAdding(false); setGuestId(g.id); }} />}
    </div>
  );
};

const Board: React.FC<{ order: GroupOrder; filter: Stage | 'All' | 'Owing'; setFilter: (f: Stage | 'All' | 'Owing') => void; open: (id: string) => void; onAdd: () => void }> = ({ order, filter, setFilter, open, onAdd }) => {
  const gs = order.guests;
  const total = gs.reduce((a, x) => a + x.price, 0), paid = gs.reduce((a, x) => a + paidOf(x), 0);
  const measured = gs.filter(x => x.stage !== 'Not measured').length, ready = gs.filter(x => ['Fitted', 'Collected'].includes(x.stage)).length;
  const shown = gs.filter(x => filter === 'All' ? true : filter === 'Owing' ? paidOf(x) < x.price : x.stage === filter);
  const summary = useMemo(() => [
    `*${order.event}* update`,
    `Measured: ${measured}/${gs.length}`, `Ready or collected: ${ready}/${gs.length}`,
    `Paid: ${naira(paid)} of ${naira(total)}`,
    `Still to be measured: ${gs.filter(x => x.stage === 'Not measured').map(x => x.name).join(', ') || 'none'}`,
  ].join('\n'), [order, measured, ready, paid, total, gs]);

  return (
    <div className="flex-1 overflow-y-auto">
      <div className="bg-gradient-to-br from-emerald-800 to-emerald-950 px-4 pb-4 pt-5 text-white">
        <p className="text-[11px] font-bold uppercase tracking-widest text-emerald-200">Group order · {daysTo(order.date)} days to go</p>
        <h1 className="mt-1 text-lg font-black leading-tight">{order.event}</h1>
        <p className="text-xs text-emerald-100">{new Date(order.date).toDateString()} · coordinator {order.coordinator}</p>
        <div className="mt-3 grid grid-cols-3 gap-2 text-center">
          <Stat k="Measured" v={`${measured}/${gs.length}`} />
          <Stat k="Ready" v={`${ready}/${gs.length}`} />
          <Stat k="Paid" v={`${Math.round((100 * paid) / total)}%`} />
        </div>
        <p className="mt-2 text-[11px] text-emerald-100">{naira(paid)} received · {naira(total - paid)} owed</p>
      </div>
      <div className="flex gap-1.5 overflow-x-auto px-3 py-2.5">
        {(['All', 'Owing', ...STAGES] as const).map(f => (
          <button key={f} onClick={() => setFilter(f)} className={`shrink-0 rounded-full px-3 py-1 text-xs font-bold ${filter === f ? 'bg-emerald-800 text-white' : 'bg-white text-stone-700 ring-1 ring-stone-200'}`}>{f}</button>
        ))}
      </div>
      <ul className="space-y-2 px-3 pb-24">
        {shown.map(x => {
          const owe = x.price - paidOf(x);
          return (
            <li key={x.id}>
              <button onClick={() => open(x.id)} className="flex w-full items-center gap-3 rounded-2xl bg-white p-3 text-left shadow-sm ring-1 ring-stone-200 active:scale-[.99]">
                <span className="flex h-9 w-9 items-center justify-center rounded-full bg-emerald-50 text-sm font-black text-emerald-800">{x.name[0]}</span>
                <span className="min-w-0 flex-1">
                  <span className="block truncate text-sm font-bold text-stone-900">{x.name}</span>
                  <span className="block truncate text-[11px] text-stone-500">{TEMPLATES.find(t => t.id === x.templateId)?.name} · {x.fabric}</span>
                  <span className="mt-1 flex items-center gap-1.5"><Pill s={x.stage} />{owe > 0 && <span className="text-[11px] font-bold text-rose-600">owes {naira(owe)}</span>}</span>
                </span>
                <ChevronRight className="h-4 w-4 text-stone-400" />
              </button>
            </li>
          );
        })}
        {!shown.length && <li className="py-8 text-center text-sm text-stone-500">Nobody here.</li>}
      </ul>
      <div className="absolute inset-x-0 bottom-0 flex gap-2 border-t border-stone-200 bg-white p-3">
        <a href={`https://wa.me/?text=${encodeURIComponent(summary)}`} target="_blank" rel="noreferrer" className="flex flex-1 items-center justify-center gap-1.5 rounded-xl bg-[#25D366] py-2.5 text-sm font-bold text-white"><MessageCircle className="h-4 w-4" /> Update coordinator</a>
        <button onClick={onAdd} className="flex items-center justify-center gap-1 rounded-xl bg-emerald-800 px-4 text-sm font-bold text-white"><Plus className="h-4 w-4" /> Guest</button>
      </div>
    </div>
  );
};

const Stat: React.FC<{ k: string; v: string }> = ({ k, v }) => (
  <div className="rounded-xl bg-white/10 py-2"><p className="text-base font-black">{v}</p><p className="text-[10px] font-semibold uppercase tracking-wide text-emerald-100">{k}</p></div>
);

const GuestScreen: React.FC<{ g: Guest; onBack: () => void; onChange: (g: Guest) => void }> = ({ g, onBack, onChange }) => {
  const tpl = TEMPLATES.find(t => t.id === g.templateId)!;
  const [tab, setTab] = useState<'measure' | 'pay' | 'fit'>('measure');
  const owe = g.price - paidOf(g);
  const idx = STAGES.indexOf(g.stage);
  return (
    <div className="flex-1 overflow-y-auto pb-6">
      <div className="flex items-center gap-2 border-b border-stone-200 bg-white px-3 py-3">
        <button onClick={onBack} aria-label="Back" className="rounded-lg p-1.5 hover:bg-stone-100"><ArrowLeft className="h-5 w-5" /></button>
        <div className="min-w-0 flex-1"><p className="truncate text-base font-black">{g.name}</p><p className="truncate text-[11px] text-stone-500">{tpl.name} · {g.fabric} · {naira(g.price)}</p></div>
        <Pill s={g.stage} />
      </div>
      <div className="px-3 pt-3">
        <p className="text-[11px] font-bold uppercase tracking-widest text-stone-400">Progress</p>
        <div className="mt-1.5 flex gap-1">{STAGES.map((s, i) => <span key={s} title={s} className={`h-1.5 flex-1 rounded-full ${i <= idx ? 'bg-emerald-600' : 'bg-stone-200'}`} />)}</div>
        {idx < STAGES.length - 1 && <button onClick={() => onChange({ ...g, stage: STAGES[idx + 1] })} className="mt-2 w-full rounded-xl bg-emerald-800 py-2 text-sm font-bold text-white">Move to: {STAGES[idx + 1]}</button>}
      </div>
      <div className="mt-3 flex gap-1 px-3">
        {([['measure', 'Measurements', Ruler], ['pay', 'Payments', Wallet], ['fit', 'Fit Record', Scissors]] as const).map(([k, label, Icon]) => (
          <button key={k} onClick={() => setTab(k)} className={`flex flex-1 items-center justify-center gap-1 rounded-xl py-2 text-xs font-bold ${tab === k ? 'bg-stone-900 text-white' : 'bg-white text-stone-600 ring-1 ring-stone-200'}`}><Icon className="h-3.5 w-3.5" /> {label}</button>
        ))}
      </div>
      <div className="px-3 pt-3">
        {tab === 'measure' && (
          <div className="rounded-2xl bg-white p-3 ring-1 ring-stone-200">
            <p className="text-xs text-stone-500">{tpl.name} template · inches</p>
            <div className="mt-2 grid grid-cols-2 gap-2">
              {tpl.fields.map(f => (
                <label key={f} className="text-[11px] font-bold text-stone-600">{f}
                  <input inputMode="decimal" value={g.measurements[f] || ''} onChange={e => onChange({ ...g, measurements: { ...g.measurements, [f]: e.target.value }, stage: g.stage === 'Not measured' ? 'Measured' : g.stage })}
                    className="mt-0.5 w-full rounded-lg border border-stone-300 px-2 py-1.5 text-sm font-semibold text-stone-900" />
                </label>
              ))}
            </div>
            <p className="mt-2 text-[11px] text-stone-500">Tip: the guest can fill these in from a link and you confirm them.</p>
          </div>
        )}
        {tab === 'pay' && <Payments g={g} owe={owe} onChange={onChange} />}
        {tab === 'fit' && <FitTab g={g} onChange={onChange} />}
      </div>
    </div>
  );
};

const Payments: React.FC<{ g: Guest; owe: number; onChange: (g: Guest) => void }> = ({ g, owe, onChange }) => {
  const [amt, setAmt] = useState('');
  return (
    <div className="rounded-2xl bg-white p-3 ring-1 ring-stone-200">
      <div className="flex justify-between text-sm"><span className="text-stone-500">Paid</span><b>{naira(paidOf(g))}</b></div>
      <div className="flex justify-between text-sm"><span className="text-stone-500">Balance</span><b className={owe > 0 ? 'text-rose-600' : 'text-emerald-700'}>{owe > 0 ? naira(owe) : 'Fully paid'}</b></div>
      <ul className="mt-2 divide-y divide-stone-100 text-xs">{g.payments.map((p, i) => <li key={i} className="flex justify-between py-1.5"><span>{p.date} · {p.method}</span><b>{naira(p.amount)}</b></li>)}</ul>
      {owe > 0 && (
        <div className="mt-2 flex gap-2">
          <input inputMode="numeric" placeholder="Amount (₦)" value={amt} onChange={e => setAmt(e.target.value.replace(/\D/g, ''))} className="min-w-0 flex-1 rounded-lg border border-stone-300 px-2 py-1.5 text-sm" />
          <button onClick={() => { const n = Number(amt); if (n > 0) { onChange({ ...g, payments: [...g.payments, { date: new Date().toISOString().slice(0, 10), amount: Math.min(n, owe), method: 'Transfer' }] }); setAmt(''); } }} className="rounded-lg bg-emerald-800 px-3 text-sm font-bold text-white">Record</button>
        </div>
      )}
    </div>
  );
};

const AREAS: FitArea[] = ['Shoulder', 'Sleeve', 'Chest / bust', 'Waist', 'Hip', 'Length', 'Neck'];
const FitTab: React.FC<{ g: Guest; onChange: (g: Guest) => void }> = ({ g, onChange }) => {
  const [area, setArea] = useState<FitArea | null>(null);
  const [cm, setCm] = useState(-1);
  const today = new Date().toISOString().slice(0, 10);
  return (
    <div className="space-y-3">
      <div className="rounded-2xl bg-white p-3 ring-1 ring-stone-200">
        <p className="text-sm font-bold">Record this fitting</p>
        <button onClick={() => onChange({ ...g, fits: [...g.fits, { date: today, approved: true }], stage: g.stage === 'Collected' ? g.stage : 'Fitted' })} className="mt-2 flex w-full items-center justify-center gap-1.5 rounded-xl bg-emerald-600 py-2.5 text-sm font-bold text-white"><Check className="h-4 w-4" /> Fits: customer approved</button>
        <p className="mt-3 text-xs font-bold text-stone-500">Or: what needs altering?</p>
        <div className="mt-1.5 flex flex-wrap gap-1.5">{AREAS.map(a => <button key={a} onClick={() => setArea(a)} className={`rounded-full px-2.5 py-1 text-xs font-bold ${area === a ? 'bg-amber-500 text-white' : 'bg-stone-100 text-stone-700'}`}>{a}</button>)}</div>
        {area && (
          <div className="mt-2 flex items-center gap-2">
            <button onClick={() => setCm(c => c - 0.5)} className="h-8 w-8 rounded-lg bg-stone-100 font-black">−</button>
            <span className="w-24 text-center text-sm font-bold">{cm > 0 ? '+' : ''}{cm} cm</span>
            <button onClick={() => setCm(c => c + 0.5)} className="h-8 w-8 rounded-lg bg-stone-100 font-black">+</button>
            <button onClick={() => { onChange({ ...g, fits: [...g.fits, { date: today, approved: false, area, changeCm: cm, note: `${cm < 0 ? 'Take in' : 'Let out'} ${Math.abs(cm)} cm at ${area.toLowerCase()}` }], stage: 'Ready for fitting' }); setArea(null); setCm(-1); }} className="ml-auto rounded-lg bg-amber-500 px-3 py-1.5 text-xs font-bold text-white">Save alteration</button>
          </div>
        )}
      </div>
      <div className="rounded-2xl bg-white p-3 ring-1 ring-stone-200">
        <p className="text-sm font-bold">Fit history</p>
        {g.fits.length ? <ul className="mt-1.5 space-y-1.5 text-xs">{g.fits.map((f, i) => <li key={i} className="flex gap-2"><span className="text-stone-500">{f.date}</span>{f.approved ? <b className="text-emerald-700">Approved</b> : <span className="text-amber-700">{f.note}</span>}</li>)}</ul>
          : <p className="mt-1 text-xs text-stone-500">No fittings yet. Each one you record here builds this customer's fit profile for {TEMPLATES.find(t => t.id === g.templateId)?.name.toLowerCase()}.</p>}
      </div>
    </div>
  );
};

const AddGuest: React.FC<{ onClose: () => void; onAdd: (g: Guest) => void }> = ({ onClose, onAdd }) => {
  const [name, setName] = useState(''), [tpl, setTpl] = useState('senator'), [fabric, setFabric] = useState('Green ankara'), [price, setPrice] = useState('30000');
  return (
    <div className="absolute inset-0 z-10 flex items-end bg-black/40" onClick={onClose}>
      <div className="w-full rounded-t-3xl bg-white p-4" onClick={e => e.stopPropagation()}>
        <p className="text-base font-black">Add a guest</p>
        <div className="mt-3 space-y-2">
          <input autoFocus placeholder="Name" value={name} onChange={e => setName(e.target.value)} className="w-full rounded-lg border border-stone-300 px-3 py-2 text-sm" />
          <select value={tpl} onChange={e => setTpl(e.target.value)} className="w-full rounded-lg border border-stone-300 px-3 py-2 text-sm">{TEMPLATES.map(t => <option key={t.id} value={t.id}>{t.name}</option>)}</select>
          <input placeholder="Fabric" value={fabric} onChange={e => setFabric(e.target.value)} className="w-full rounded-lg border border-stone-300 px-3 py-2 text-sm" />
          <input inputMode="numeric" placeholder="Price (₦)" value={price} onChange={e => setPrice(e.target.value.replace(/\D/g, ''))} className="w-full rounded-lg border border-stone-300 px-3 py-2 text-sm" />
        </div>
        <button disabled={!name.trim()} onClick={() => onAdd({ id: String(Date.now()), name: name.trim(), phone: '', templateId: tpl, fabric, price: Number(price) || 0, stage: 'Not measured', measurements: {}, payments: [], fits: [] })} className="mt-3 w-full rounded-xl bg-emerald-800 py-2.5 text-sm font-bold text-white disabled:opacity-40">Add guest</button>
      </div>
    </div>
  );
};
