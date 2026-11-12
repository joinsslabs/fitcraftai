// Sample data for the clickable prototype. Every name, order and amount is fictional.
export type Stage = 'Not measured' | 'Measured' | 'Cutting' | 'Sewing' | 'Ready for fitting' | 'Fitted' | 'Collected';
export const STAGES: Stage[] = ['Not measured', 'Measured', 'Cutting', 'Sewing', 'Ready for fitting', 'Fitted', 'Collected'];

export interface Template { id: string; name: string; fields: string[] }
export const TEMPLATES: Template[] = [
  { id: 'agbada', name: 'Agbada (3-piece)', fields: ['Chest', 'Shoulder', 'Sleeve', 'Agbada length', 'Top length', 'Trouser waist', 'Trouser length', 'Thigh', 'Cap'] },
  { id: 'buba-iro', name: 'Buba and iro', fields: ['Bust', 'Waist', 'Hip', 'Shoulder', 'Sleeve', 'Blouse length', 'Wrapper length'] },
  { id: 'senator', name: 'Senator', fields: ['Chest', 'Shoulder', 'Sleeve', 'Top length', 'Neck', 'Trouser waist', 'Trouser length'] },
  { id: 'gown', name: 'Gown', fields: ['Bust', 'Under-bust', 'Waist', 'Hip', 'Shoulder', 'Gown length'] },
];

export type FitArea = 'Shoulder' | 'Sleeve' | 'Chest / bust' | 'Waist' | 'Hip' | 'Length' | 'Neck';
export interface FitRecord { date: string; approved: boolean; area?: FitArea; changeCm?: number; note?: string }
export interface Payment { date: string; amount: number; method: 'Transfer' | 'Cash' | 'POS' }

export interface Guest {
  id: string; name: string; phone: string; templateId: string; fabric: string; price: number;
  stage: Stage; measurements: Record<string, string>; payments: Payment[]; fits: FitRecord[]; fittingDate?: string;
}
export interface GroupOrder { id: string; event: string; date: string; coordinator: string; coordinatorPhone: string; fabricNote: string; guests: Guest[] }

const g = (id: string, name: string, templateId: string, fabric: string, price: number, stage: Stage, paid: number[], extra: Partial<Guest> = {}): Guest => ({
  id, name, phone: '0803 000 0000', templateId, fabric, price, stage,
  measurements: stage === 'Not measured' ? {} : sampleMeasures(templateId),
  payments: paid.map((amount, i) => ({ date: `2026-11-0${i + 2}`, amount, method: i ? 'Cash' : 'Transfer' })),
  fits: [], ...extra,
});

function sampleMeasures(t: string): Record<string, string> {
  const base: Record<string, string> = { Chest: '42', Bust: '38', 'Under-bust': '33', Waist: '34', Hip: '42', Shoulder: '18', Sleeve: '24', 'Agbada length': '58', 'Top length': '30', 'Blouse length': '24', 'Wrapper length': '42', 'Gown length': '58', 'Trouser waist': '34', 'Trouser length': '40', Thigh: '25', Neck: '16', Cap: '22' };
  const tpl = TEMPLATES.find(x => x.id === t)!;
  return Object.fromEntries(tpl.fields.map(f => [f, base[f] ?? '']));
}

export const SEED: GroupOrder = {
  id: 'go-1', event: 'Bisi & Kunle wedding (sample)', date: '2026-12-19', coordinator: 'Aunty Funke (sample)', coordinatorPhone: '',
  fabricNote: 'Gold aso-oke for family, green ankara for friends',
  guests: [
    g('1', 'Kunle (groom)', 'agbada', 'Gold aso-oke', 85000, 'Sewing', [85000]),
    g('2', 'Bisi (bride)', 'gown', 'Gold aso-oke', 120000, 'Ready for fitting', [60000, 60000], { fittingDate: '2026-12-05' }),
    g('3', 'Mama Bisi', 'buba-iro', 'Gold aso-oke', 65000, 'Fitted', [65000], { fits: [{ date: '2026-11-28', approved: false, area: 'Waist', changeCm: -2, note: 'Took in 2 cm at waist' }, { date: '2026-11-30', approved: true }] }),
    g('4', 'Baba Kunle', 'agbada', 'Gold aso-oke', 85000, 'Cutting', [40000]),
    g('5', 'Tolu', 'buba-iro', 'Green ankara', 35000, 'Measured', [35000]),
    g('6', 'Emeka', 'senator', 'Green ankara', 30000, 'Measured', [15000]),
    g('7', 'Zainab', 'gown', 'Green ankara', 40000, 'Not measured', []),
    g('8', 'Ade', 'senator', 'Green ankara', 30000, 'Not measured', [30000]),
    g('9', 'Ngozi', 'buba-iro', 'Green ankara', 35000, 'Collected', [35000], { fits: [{ date: '2026-11-20', approved: true }] }),
    g('10', 'Seyi', 'senator', 'Green ankara', 30000, 'Sewing', [30000]),
  ],
};

export const naira = (n: number) => '₦' + n.toLocaleString('en-NG');
export const paidOf = (x: Guest) => x.payments.reduce((a, p) => a + p.amount, 0);
export const daysTo = (d: string) => Math.ceil((Date.parse(d) - Date.now()) / 864e5);
