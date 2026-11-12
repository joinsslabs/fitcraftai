import React, { useEffect, useState } from 'react';
import { RotateCcw, Smartphone, Users, Info } from 'lucide-react';
import { GroupOrder, SEED, Stage, TEMPLATES, daysTo, naira, paidOf } from './data';
import { TailorApp } from './TailorApp';

const KEY = 'fitcraft_proto_v1';
const load = (): GroupOrder => { try { return JSON.parse(localStorage.getItem(KEY) || '') as GroupOrder; } catch { return SEED; } };

export default function App() {
  const [order, setOrder] = useState<GroupOrder>(load);
  const [view, setView] = useState<'tailor' | 'coordinator' | 'about'>('tailor');
  const [offline, setOffline] = useState(false);
  useEffect(() => { try { localStorage.setItem(KEY, JSON.stringify(order)); } catch { /* storage blocked */ } }, [order]);

  return (
    <div className="min-h-screen px-4 py-6">
      <header className="mx-auto flex max-w-5xl flex-wrap items-center justify-between gap-3">
        <div>
          <p className="text-[11px] font-black uppercase tracking-[0.2em] text-emerald-700">FitCraft AI · clickable prototype</p>
          <h1 className="text-xl font-black text-stone-900">Run your next Aso-ebi order without the WhatsApp chaos</h1>
        </div>
        <div className="flex flex-wrap gap-2 text-xs font-bold">
          {([['tailor', 'Tailor app', Smartphone], ['coordinator', 'Coordinator link', Users], ['about', 'About', Info]] as const).map(([k, label, Icon]) => (
            <button key={k} onClick={() => setView(k)} className={`inline-flex items-center gap-1.5 rounded-full px-3 py-1.5 ${view === k ? 'bg-stone-900 text-white' : 'bg-white text-stone-700 ring-1 ring-stone-300'}`}><Icon className="h-3.5 w-3.5" /> {label}</button>
          ))}
          <label className="inline-flex items-center gap-1.5 rounded-full bg-white px-3 py-1.5 text-stone-700 ring-1 ring-stone-300"><input type="checkbox" checked={offline} onChange={e => setOffline(e.target.checked)} /> Simulate offline</label>
          <button onClick={() => { if (confirm('Reset the sample data?')) setOrder(SEED); }} className="inline-flex items-center gap-1.5 rounded-full bg-white px-3 py-1.5 text-stone-700 ring-1 ring-stone-300"><RotateCcw className="h-3.5 w-3.5" /> Reset</button>
        </div>
      </header>

      <main className="mx-auto mt-6 flex max-w-5xl justify-center">
        {view === 'tailor' && (
          <div className="relative h-[760px] w-[380px] max-w-full overflow-hidden rounded-[2.5rem] border-[10px] border-stone-900 bg-stone-50 shadow-2xl">
            <TailorApp order={order} setOrder={setOrder} offline={offline} />
          </div>
        )}
        {view === 'coordinator' && <Coordinator order={order} />}
        {view === 'about' && <About />}
      </main>
      <p className="mx-auto mt-6 max-w-5xl text-center text-[11px] text-stone-500">Prototype for user research. All names, orders and amounts are sample data, saved only in this browser.</p>
    </div>
  );
}

const DONE: Stage[] = ['Fitted', 'Collected'];
const Coordinator: React.FC<{ order: GroupOrder }> = ({ order }) => {
  const gs = order.guests;
  const owing = gs.filter(x => paidOf(x) < x.price);
  return (
    <div className="w-full max-w-xl rounded-3xl bg-white p-5 shadow-xl ring-1 ring-stone-200">
      <p className="text-[11px] font-bold uppercase tracking-widest text-emerald-700">Live status · shared by your tailor</p>
      <h2 className="mt-1 text-xl font-black">{order.event}</h2>
      <p className="text-sm text-stone-500">{new Date(order.date).toDateString()} · {daysTo(order.date)} days to go</p>
      <div className="mt-4 grid grid-cols-3 gap-2 text-center">
        <Box k="Measured" v={`${gs.filter(x => x.stage !== 'Not measured').length}/${gs.length}`} />
        <Box k="Ready" v={`${gs.filter(x => DONE.includes(x.stage)).length}/${gs.length}`} />
        <Box k="Still owing" v={String(owing.length)} />
      </div>
      <table className="mt-4 w-full text-sm">
        <thead><tr className="text-left text-[11px] uppercase tracking-wide text-stone-400"><th className="py-1">Guest</th><th>Outfit</th><th>Status</th><th className="text-right">Payment</th></tr></thead>
        <tbody className="divide-y divide-stone-100">
          {gs.map(x => {
            const owe = x.price - paidOf(x);
            return (
              <tr key={x.id}>
                <td className="py-2 font-semibold">{x.name}</td>
                <td className="text-xs text-stone-500">{TEMPLATES.find(t => t.id === x.templateId)?.name}</td>
                <td className="text-xs">{x.stage}{x.fittingDate && x.stage === 'Ready for fitting' ? ` (${x.fittingDate})` : ''}</td>
                <td className={`text-right text-xs font-bold ${owe > 0 ? 'text-rose-600' : 'text-emerald-700'}`}>{owe > 0 ? `owes ${naira(owe)}` : 'paid'}</td>
              </tr>
            );
          })}
        </tbody>
      </table>
      <p className="mt-4 text-xs text-stone-500">No app to install. This page updates as the tailor works. Measurements are not shown here: they stay private between each guest and the tailor.</p>
    </div>
  );
};
const Box: React.FC<{ k: string; v: string }> = ({ k, v }) => <div className="rounded-xl bg-emerald-50 py-3"><p className="text-xl font-black text-emerald-900">{v}</p><p className="text-[11px] font-semibold text-emerald-800">{k}</p></div>;

const About: React.FC = () => (
  <div className="w-full max-w-xl space-y-3 rounded-3xl bg-white p-6 text-sm leading-relaxed text-stone-700 shadow-xl ring-1 ring-stone-200">
    <h2 className="text-lg font-black text-stone-900">What to test with tailors</h2>
    <ol className="list-decimal space-y-1.5 pl-5">
      <li>Ask them to find who has not been measured and who still owes money. Time it.</li>
      <li>Ask them to record a part-payment and move a guest to the next stage.</li>
      <li>Ask them to record a fitting where the waist needs taking in by 2 cm.</li>
      <li>Show the coordinator link. Ask: would your coordinators use this instead of calling you?</li>
      <li>Ask: what would you pay a month for this? What is missing?</li>
    </ol>
    <p>Not in the prototype yet: real sync, guest measurement links, WhatsApp Business messages, scans, accounts.</p>
  </div>
);
