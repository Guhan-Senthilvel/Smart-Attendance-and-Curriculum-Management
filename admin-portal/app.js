const API_BASE = "http://10.252.159.201:8000/api";




// =============================================
// UTILITY HOOKS
// =============================================

function useFetchList(url) {
  const [items, setItems] = React.useState([]);
  const [loading, setLoading] = React.useState(false);
  const [error, setError] = React.useState(null);

  const fetchItems = React.useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const token = localStorage.getItem("admin_token");
      if (!token) throw new Error("No token found");

      const res = await fetch(url, {
        headers: { "Authorization": `Bearer ${token}` }
      });

      if (res.status === 401 || res.status === 403) {
        localStorage.removeItem("admin_token");
        window.location.reload();
        throw new Error("Session expired. Please login again.");
      }

      if (!res.ok) throw new Error(await res.text());
      const text = await res.text();
      console.log(`[useFetchList] ${url} Raw Response:`, text);
      const data = text ? JSON.parse(text) : [];
      setItems(data);
    } catch (e) {
      setError(e.message || "Failed to load");
    } finally {
      setLoading(false);
    }
  }, [url]);

  React.useEffect(() => {
    fetchItems();
  }, [fetchItems]);

  return { items, loading, error, refetch: fetchItems };
}

// Helper for authenticated requests
async function authFetch(url, options = {}) {
  const token = localStorage.getItem("admin_token");
  const headers = {
    ...options.headers,
    "Authorization": `Bearer ${token}`
  };

  const res = await fetch(url, { ...options, headers });

  if (res.status === 401 || res.status === 403) {
    localStorage.removeItem("admin_token");
    window.location.reload();
    throw new Error("Session expired");
  }
  return res;
}

function useNotification() {
  const [notification, setNotification] = React.useState(null);
  const showSuccess = (msg) => { setNotification({ type: "success", message: msg }); setTimeout(() => setNotification(null), 4000); };
  const showError = (msg) => { setNotification({ type: "error", message: msg }); setTimeout(() => setNotification(null), 5000); };
  return { notification, showSuccess, showError };
}

// =============================================
// EDIT MODAL COMPONENT
// =============================================

function EditModal({ title, fields, values, onSave, onClose }) {
  const [formData, setFormData] = React.useState(values || {});
  const [saving, setSaving] = React.useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSaving(true);
    await onSave(formData);
    setSaving(false);
  };

  return (
    <div style={{ position: "fixed", top: 0, left: 0, right: 0, bottom: 0, background: "rgba(0,0,0,0.7)", display: "flex", alignItems: "center", justifyContent: "center", zIndex: 1000 }}>
      <div className="card" style={{ maxWidth: "500px", width: "90%", maxHeight: "80vh", overflow: "auto" }}>
        <div className="card-header">
          <div className="card-title">{title}</div>
        </div>
        <form onSubmit={handleSubmit}>
          <div className="form-grid">
            {fields.map(f => (
              <div className="field" key={f.name}>
                <label>{f.label}</label>
                {f.type === "select" ? (
                  <select value={formData[f.name] || ""} onChange={e => setFormData({ ...formData, [f.name]: e.target.value })}>
                    <option value="">Select</option>
                    {f.options.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
                  </select>
                ) : (
                  <input type={f.type || "text"} value={formData[f.name] || ""} onChange={e => setFormData({ ...formData, [f.name]: e.target.value })} />
                )}
              </div>
            ))}
          </div>
          <div style={{ display: "flex", gap: "12px", marginTop: "16px" }}>
            <button type="submit" className="primary-button" disabled={saving}>{saving ? "Saving..." : "Save Changes"}</button>
            <button type="button" className="secondary-button" onClick={onClose}>Cancel</button>
          </div>
        </form>
      </div>
    </div>
  );
}

// =============================================
// DEPARTMENTS SECTION
// =============================================

function DepartmentsSection() {
  const { items, loading, error, refetch } = useFetchList(`${API_BASE}/admin/departments`);
  const [name, setName] = React.useState("");
  const [saving, setSaving] = React.useState(false);
  const [editItem, setEditItem] = React.useState(null);
  const { notification, showSuccess, showError } = useNotification();

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!name.trim()) return;
    try {
      setSaving(true);
      const res = await authFetch(`${API_BASE}/admin/departments`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ dept_name: name.trim() }) });
      if (!res.ok) throw new Error(await res.text());
      setName(""); showSuccess("Department created!"); refetch();
    } catch (e) { showError(e.message); } finally { setSaving(false); }
  };

  const handleDelete = async (id) => {
    if (!confirm("Delete?")) return;
    try { const res = await authFetch(`${API_BASE}/admin/departments/${id}`, { method: "DELETE" }); if (!res.ok) throw new Error(await res.text()); showSuccess("Deleted"); refetch(); } catch (e) { showError(e.message); }
  };

  const handleEdit = async (data) => {
    try {
      const res = await authFetch(`${API_BASE}/admin/departments/${editItem.dept_id}`, { method: "PUT", headers: { "Content-Type": "application/json" }, body: JSON.stringify(data) });
      if (!res.ok) throw new Error(await res.text()); setEditItem(null); showSuccess("Updated!"); refetch();
    } catch (e) { showError(e.message); }
  };

  return (
    <div className="card">
      <div className="card-header"><div><div className="card-title">Departments</div><div className="card-subtitle">Manage college departments</div></div></div>
      {notification && <div className={`alert alert-${notification.type}`}>{notification.message}</div>}
      <form onSubmit={handleSubmit}>
        <div className="form-grid">
          <div className="field"><label>Department Name</label><input value={name} onChange={e => setName(e.target.value)} placeholder="e.g. Computer Science" /></div>
        </div>
        <button className="primary-button" disabled={saving}>{saving ? "Saving..." : "Add Department"}</button>
      </form>
      <div className="status-bar">{loading ? "Loading..." : error ? <span className="error">{error}</span> : `${items.length} departments`}</div>
      <table className="table"><thead><tr><th>ID</th><th>Name</th><th>Actions</th></tr></thead><tbody>
        {items.map(d => (<tr key={d.dept_id}><td>{d.dept_id}</td><td>{d.dept_name}</td><td>
          <button className="secondary-button" onClick={() => setEditItem(d)}>Edit</button>
          <button className="danger-button" style={{ marginLeft: "8px" }} onClick={() => handleDelete(d.dept_id)}>Delete</button>
        </td></tr>))}
      </tbody></table>
      {editItem && <EditModal title="Edit Department" fields={[{ name: "dept_name", label: "Department Name" }]} values={{ dept_name: editItem.dept_name }} onSave={handleEdit} onClose={() => setEditItem(null)} />}
    </div>
  );
}

// =============================================
// BATCHES SECTION
// =============================================

function BatchesSection() {
  const { items, loading, error, refetch } = useFetchList(`${API_BASE}/admin/batches`);
  const [startYear, setStartYear] = React.useState(""); const [endYear, setEndYear] = React.useState("");
  const [saving, setSaving] = React.useState(false); const [editItem, setEditItem] = React.useState(null);
  const { notification, showSuccess, showError } = useNotification();

  const handleSubmit = async (e) => {
    e.preventDefault(); if (!startYear || !endYear) return;
    try {
      setSaving(true); const res = await authFetch(`${API_BASE}/admin/batches`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ start_year: Number(startYear), end_year: Number(endYear) }) });
      if (!res.ok) throw new Error(await res.text()); setStartYear(""); setEndYear(""); showSuccess("Batch created!"); refetch();
    } catch (e) { showError(e.message); } finally { setSaving(false); }
  };

  const handleDelete = async (id) => { if (!confirm("Delete?")) return; try { const res = await authFetch(`${API_BASE}/admin/batches/${id}`, { method: "DELETE" }); if (!res.ok) throw new Error(await res.text()); showSuccess("Deleted"); refetch(); } catch (e) { showError(e.message); } };

  const handleEdit = async (data) => {
    try {
      const res = await authFetch(`${API_BASE}/admin/batches/${editItem.batch_id}`, { method: "PUT", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ start_year: Number(data.start_year), end_year: Number(data.end_year) }) });
      if (!res.ok) throw new Error(await res.text()); setEditItem(null); showSuccess("Updated!"); refetch();
    } catch (e) { showError(e.message); }
  };

  return (
    <div className="card">
      <div className="card-header"><div><div className="card-title">Batches</div><div className="card-subtitle">Define batch periods</div></div></div>
      {notification && <div className={`alert alert-${notification.type}`}>{notification.message}</div>}
      <form onSubmit={handleSubmit}>
        <div className="form-grid">
          <div className="field"><label>Start Year</label><input type="number" placeholder="2022" value={startYear} onChange={e => setStartYear(e.target.value)} /></div>
          <div className="field"><label>End Year</label><input type="number" placeholder="2026" value={endYear} onChange={e => setEndYear(e.target.value)} /></div>
        </div>
        <button className="primary-button" disabled={saving}>{saving ? "Saving..." : "Add Batch"}</button>
      </form>
      <div className="status-bar">{loading ? "Loading..." : `${items.length} batches`}</div>
      <table className="table"><thead><tr><th>ID</th><th>Start</th><th>End</th><th>Actions</th></tr></thead><tbody>
        {items.map(b => (<tr key={b.batch_id}><td>{b.batch_id}</td><td>{b.start_year}</td><td>{b.end_year}</td><td>
          <button className="secondary-button" onClick={() => setEditItem(b)}>Edit</button>
          <button className="danger-button" style={{ marginLeft: "8px" }} onClick={() => handleDelete(b.batch_id)}>Delete</button>
        </td></tr>))}
      </tbody></table>
      {editItem && <EditModal title="Edit Batch" fields={[{ name: "start_year", label: "Start Year", type: "number" }, { name: "end_year", label: "End Year", type: "number" }]} values={{ start_year: editItem.start_year, end_year: editItem.end_year }} onSave={handleEdit} onClose={() => setEditItem(null)} />}
    </div>
  );
}

// =============================================
// CLASSES SECTION
// =============================================

function ClassesSection() {
  const { items: departments } = useFetchList(`${API_BASE}/admin/departments`);
  const { items: batches } = useFetchList(`${API_BASE}/admin/batches`);
  const { items: classes, loading, error, refetch } = useFetchList(`${API_BASE}/admin/classes`);
  const [classId, setClassId] = React.useState(""); const [deptId, setDeptId] = React.useState(""); const [batchId, setBatchId] = React.useState("");
  const [year, setYear] = React.useState(""); const [section, setSection] = React.useState("");
  const [saving, setSaving] = React.useState(false); const [editItem, setEditItem] = React.useState(null);
  const { notification, showSuccess, showError } = useNotification();

  const handleSubmit = async (e) => {
    e.preventDefault(); if (!classId || !deptId || !batchId || !year || !section) { showError("Fill all fields"); return; }
    try {
      setSaving(true); const res = await authFetch(`${API_BASE}/admin/classes`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ class_id: classId.trim(), dept_id: Number(deptId), batch_id: Number(batchId), year: Number(year), section: section.trim().toUpperCase() }) });
      if (!res.ok) throw new Error(await res.text()); setClassId(""); setYear(""); setSection(""); showSuccess("Created!"); refetch();
    } catch (e) { showError(e.message); } finally { setSaving(false); }
  };

  const handleDelete = async (id) => { if (!confirm("Delete?")) return; try { const res = await authFetch(`${API_BASE}/admin/classes/${id}`, { method: "DELETE" }); if (!res.ok) throw new Error(await res.text()); showSuccess("Deleted"); refetch(); } catch (e) { showError(e.message); } };

  const handleEdit = async (data) => {
    try {
      const res = await authFetch(`${API_BASE}/admin/classes/${editItem.class_id}`, { method: "PUT", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ dept_id: Number(data.dept_id), batch_id: Number(data.batch_id), year: Number(data.year), section: data.section }) });
      if (!res.ok) throw new Error(await res.text()); setEditItem(null); showSuccess("Updated!"); refetch();
    } catch (e) { showError(e.message); }
  };

  const deptById = Object.fromEntries(departments.map(d => [d.dept_id, d.dept_name]));
  const batchById = Object.fromEntries(batches.map(b => [b.batch_id, `${b.start_year}-${b.end_year}`]));

  return (
    <div className="card">
      <div className="card-header"><div><div className="card-title">Classes</div><div className="card-subtitle">Create classes with your own IDs</div></div></div>
      {notification && <div className={`alert alert-${notification.type}`}>{notification.message}</div>}
      <form onSubmit={handleSubmit}>
        <div className="form-grid">
          <div className="field"><label>Class ID</label><input value={classId} onChange={e => setClassId(e.target.value)} placeholder="CSE-4-A" /></div>
          <div className="field"><label>Department</label><select value={deptId} onChange={e => setDeptId(e.target.value)}><option value="">Select</option>{departments.map(d => <option key={d.dept_id} value={d.dept_id}>{d.dept_name}</option>)}</select></div>
          <div className="field"><label>Batch</label><select value={batchId} onChange={e => setBatchId(e.target.value)}><option value="">Select</option>{batches.map(b => <option key={b.batch_id} value={b.batch_id}>{b.start_year}-{b.end_year}</option>)}</select></div>
          <div className="field"><label>Year</label><select value={year} onChange={e => setYear(e.target.value)}><option value="">Select</option><option value="1">1st</option><option value="2">2nd</option><option value="3">3rd</option><option value="4">4th</option></select></div>
          <div className="field"><label>Section</label><input value={section} onChange={e => setSection(e.target.value)} placeholder="A" maxLength={2} /></div>
        </div>
        <button className="primary-button" disabled={saving}>{saving ? "Saving..." : "Add Class"}</button>
      </form>
      <div className="status-bar">{loading ? "Loading..." : `${classes.length} classes`}</div>
      <table className="table"><thead><tr><th>Class ID</th><th>Dept</th><th>Batch</th><th>Year</th><th>Section</th><th>Actions</th></tr></thead><tbody>
        {classes.map(c => (<tr key={c.class_id}><td><strong>{c.class_id}</strong></td><td>{deptById[c.dept_id]}</td><td>{batchById[c.batch_id]}</td><td>Y{c.year}</td><td>{c.section}</td><td>
          <button className="secondary-button" onClick={() => setEditItem(c)}>Edit</button>
          <button className="danger-button" style={{ marginLeft: "8px" }} onClick={() => handleDelete(c.class_id)}>Delete</button>
        </td></tr>))}
      </tbody></table>
      {editItem && <EditModal title="Edit Class" fields={[{ name: "dept_id", label: "Department", type: "select", options: departments.map(d => ({ value: d.dept_id, label: d.dept_name })) }, { name: "batch_id", label: "Batch", type: "select", options: batches.map(b => ({ value: b.batch_id, label: `${b.start_year}-${b.end_year}` })) }, { name: "year", label: "Year", type: "select", options: [{ value: 1, label: "1st" }, { value: 2, label: "2nd" }, { value: 3, label: "3rd" }, { value: 4, label: "4th" }] }, { name: "section", label: "Section" }]} values={{ dept_id: editItem.dept_id, batch_id: editItem.batch_id, year: editItem.year, section: editItem.section }} onSave={handleEdit} onClose={() => setEditItem(null)} />}
    </div>
  );
}

// =============================================
// STUDENTS SECTION
// =============================================

function StudentsSection() {
  const { items: departments } = useFetchList(`${API_BASE}/admin/departments`);
  const { items: batches } = useFetchList(`${API_BASE}/admin/batches`);
  const { items: classes } = useFetchList(`${API_BASE}/admin/classes`);
  const { items: students, loading, error, refetch } = useFetchList(`${API_BASE}/admin/students`);
  const [regNo, setRegNo] = React.useState(""); const [name, setName] = React.useState(""); const [deptId, setDeptId] = React.useState("");
  const [batchId, setBatchId] = React.useState(""); const [classId, setClassId] = React.useState(""); const [email, setEmail] = React.useState(""); const [password, setPassword] = React.useState("");
  const [saving, setSaving] = React.useState(false); const [editItem, setEditItem] = React.useState(null);
  const { notification, showSuccess, showError } = useNotification();
  const filteredClasses = classes.filter(c => (!deptId || c.dept_id === Number(deptId)) && (!batchId || c.batch_id === Number(batchId)));

  const handleSubmit = async (e) => {
    e.preventDefault(); if (!regNo || !name || !deptId || !batchId || !classId || !email || !password) { showError("Fill all fields"); return; }
    try {
      setSaving(true); const res = await authFetch(`${API_BASE}/admin/students`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ reg_no: regNo.trim(), name: name.trim(), dept_id: Number(deptId), batch_id: Number(batchId), class_id: classId, email: email.trim(), password }) });
      if (!res.ok) throw new Error(await res.text()); setRegNo(""); setName(""); setEmail(""); setPassword(""); showSuccess("Student created!"); refetch();
    } catch (e) { showError(e.message); } finally { setSaving(false); }
  };

  const handleDelete = async (id) => { if (!confirm("Delete?")) return; try { const res = await authFetch(`${API_BASE}/admin/students/${id}`, { method: "DELETE" }); if (!res.ok) throw new Error(await res.text()); showSuccess("Deleted"); refetch(); } catch (e) { showError(e.message); } };

  const handleEdit = async (data) => {
    try {
      const res = await authFetch(`${API_BASE}/admin/students/${editItem.reg_no}`, { method: "PUT", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ name: data.name, dept_id: Number(data.dept_id), batch_id: Number(data.batch_id), class_id: data.class_id }) });
      if (!res.ok) throw new Error(await res.text()); setEditItem(null); showSuccess("Updated!"); refetch();
    } catch (e) { showError(e.message); }
  };

  const deptById = Object.fromEntries(departments.map(d => [d.dept_id, d.dept_name]));

  return (
    <div className="card">
      <div className="card-header"><div><div className="card-title">Students</div><div className="card-subtitle">Register students</div></div></div>
      {notification && <div className={`alert alert-${notification.type}`}>{notification.message}</div>}
      <form onSubmit={handleSubmit}>
        <div className="form-grid">
          <div className="field"><label>Reg No</label><input value={regNo} onChange={e => setRegNo(e.target.value)} placeholder="720722104095" /></div>
          <div className="field"><label>Name</label><input value={name} onChange={e => setName(e.target.value)} placeholder="John Doe" /></div>
          <div className="field"><label>Dept</label><select value={deptId} onChange={e => setDeptId(e.target.value)}><option value="">Select</option>{departments.map(d => <option key={d.dept_id} value={d.dept_id}>{d.dept_name}</option>)}</select></div>
          <div className="field"><label>Batch</label><select value={batchId} onChange={e => setBatchId(e.target.value)}><option value="">Select</option>{batches.map(b => <option key={b.batch_id} value={b.batch_id}>{b.start_year}-{b.end_year}</option>)}</select></div>
          <div className="field"><label>Class</label><select value={classId} onChange={e => setClassId(e.target.value)}><option value="">Select</option>{filteredClasses.map(c => <option key={c.class_id} value={c.class_id}>Class {c.class_id}</option>)}</select></div>
          <div className="field"><label>Email</label><input type="email" value={email} onChange={e => setEmail(e.target.value)} placeholder="student@email.com" /></div>
          <div className="field"><label>Password</label><input type="password" value={password} onChange={e => setPassword(e.target.value)} placeholder="••••••" /></div>
        </div>
        <button className="primary-button" disabled={saving}>{saving ? "Saving..." : "Add Student"}</button>
      </form>
      <div className="status-bar">{loading ? "Loading..." : `${students.length} students`}</div>
      <table className="table"><thead><tr><th>Reg No</th><th>Name</th><th>Dept</th><th>Class</th><th>Actions</th></tr></thead><tbody>
        {students.slice(0, 50).map(s => (<tr key={s.student_id}><td><strong>{s.reg_no}</strong></td><td>{s.name}</td><td>{deptById[s.dept_id]}</td><td>{s.class_id}</td><td>
          <button className="secondary-button" onClick={() => setEditItem(s)}>Edit</button>
          <button className="danger-button" style={{ marginLeft: "8px" }} onClick={() => handleDelete(s.reg_no)}>Delete</button>
        </td></tr>))}
      </tbody></table>
      {editItem && <EditModal title="Edit Student" fields={[{ name: "name", label: "Name" }, { name: "dept_id", label: "Department", type: "select", options: departments.map(d => ({ value: d.dept_id, label: d.dept_name })) }, { name: "batch_id", label: "Batch", type: "select", options: batches.map(b => ({ value: b.batch_id, label: `${b.start_year}-${b.end_year}` })) }, { name: "class_id", label: "Class", type: "select", options: classes.map(c => ({ value: c.class_id, label: `Class ${c.class_id}` })) }]} values={{ name: editItem.name, dept_id: editItem.dept_id, batch_id: editItem.batch_id, class_id: editItem.class_id }} onSave={handleEdit} onClose={() => setEditItem(null)} />}
    </div>
  );
}

// =============================================
// TEACHERS SECTION (with name field)
// =============================================

function TeachersSection() {
  const { items: departments } = useFetchList(`${API_BASE}/admin/departments`);
  const { items: teachers, loading, error, refetch } = useFetchList(`${API_BASE}/admin/teachers`);
  const [employeeNo, setEmployeeNo] = React.useState(""); const [name, setName] = React.useState(""); const [deptId, setDeptId] = React.useState(""); const [email, setEmail] = React.useState(""); const [password, setPassword] = React.useState("");
  const [saving, setSaving] = React.useState(false); const [editItem, setEditItem] = React.useState(null);
  const { notification, showSuccess, showError } = useNotification();

  const handleSubmit = async (e) => {
    e.preventDefault(); if (!employeeNo || !name || !deptId || !email || !password) { showError("Fill all fields"); return; }
    try {
      setSaving(true); const res = await authFetch(`${API_BASE}/admin/teachers`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ employee_no: employeeNo.trim(), name: name.trim(), dept_id: Number(deptId), email: email.trim(), password }) });
      if (!res.ok) throw new Error(await res.text()); setEmployeeNo(""); setName(""); setEmail(""); setPassword(""); showSuccess("Teacher created!"); refetch();
    } catch (e) { showError(e.message); } finally { setSaving(false); }
  };

  const handleDelete = async (id) => { if (!confirm("Delete?")) return; try { const res = await authFetch(`${API_BASE}/admin/teachers/${id}`, { method: "DELETE" }); if (!res.ok) throw new Error(await res.text()); showSuccess("Deleted"); refetch(); } catch (e) { showError(e.message); } };

  const handleEdit = async (data) => {
    try {
      const res = await authFetch(`${API_BASE}/admin/teachers/${editItem.teacher_id}`, { method: "PUT", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ name: data.name, dept_id: Number(data.dept_id) }) });
      if (!res.ok) throw new Error(await res.text()); setEditItem(null); showSuccess("Updated!"); refetch();
    } catch (e) { showError(e.message); }
  };

  const deptById = Object.fromEntries(departments.map(d => [d.dept_id, d.dept_name]));

  return (
    <div className="card">
      <div className="card-header"><div><div className="card-title">Teachers</div><div className="card-subtitle">Register teachers with credentials</div></div></div>
      {notification && <div className={`alert alert-${notification.type}`}>{notification.message}</div>}
      <form onSubmit={handleSubmit}>
        <div className="form-grid">
          <div className="field"><label>Employee No</label><input value={employeeNo} onChange={e => setEmployeeNo(e.target.value)} placeholder="EMP001" /></div>
          <div className="field"><label>Teacher Name</label><input value={name} onChange={e => setName(e.target.value)} placeholder="Dr. John Smith" /></div>
          <div className="field"><label>Department</label><select value={deptId} onChange={e => setDeptId(e.target.value)}><option value="">Select</option>{departments.map(d => <option key={d.dept_id} value={d.dept_id}>{d.dept_name}</option>)}</select></div>
          <div className="field"><label>Email</label><input type="email" value={email} onChange={e => setEmail(e.target.value)} placeholder="teacher@email.com" /></div>
          <div className="field"><label>Password</label><input type="password" value={password} onChange={e => setPassword(e.target.value)} placeholder="••••••" /></div>
        </div>
        <button className="primary-button" disabled={saving}>{saving ? "Saving..." : "Add Teacher"}</button>
      </form>
      <div className="status-bar">{loading ? "Loading..." : `${teachers.length} teachers`}</div>
      <table className="table"><thead><tr><th>ID</th><th>Emp No</th><th>Name</th><th>Dept</th><th>Actions</th></tr></thead><tbody>
        {teachers.map(t => (<tr key={t.teacher_id}><td>{t.teacher_id}</td><td>{t.employee_no}</td><td><strong>{t.name}</strong></td><td>{deptById[t.dept_id]}</td><td>
          <button className="secondary-button" onClick={() => setEditItem(t)}>Edit</button>
          <button className="danger-button" style={{ marginLeft: "8px" }} onClick={() => handleDelete(t.teacher_id)}>Delete</button>
        </td></tr>))}
      </tbody></table>
      {editItem && <EditModal title="Edit Teacher" fields={[{ name: "name", label: "Name" }, { name: "dept_id", label: "Department", type: "select", options: departments.map(d => ({ value: d.dept_id, label: d.dept_name })) }]} values={{ name: editItem.name, dept_id: editItem.dept_id }} onSave={handleEdit} onClose={() => setEditItem(null)} />}
    </div>
  );
}

// =============================================
// SUBJECTS SECTION
// =============================================

function SubjectsSection() {
  const { items: departments } = useFetchList(`${API_BASE}/admin/departments`);
  const { items: subjects, loading, error, refetch } = useFetchList(`${API_BASE}/admin/subjects`);
  const [subjectCode, setSubjectCode] = React.useState(""); const [subjectName, setSubjectName] = React.useState(""); const [credits, setCredits] = React.useState("");
  const [deptId, setDeptId] = React.useState(""); const [semester, setSemester] = React.useState("");
  const [saving, setSaving] = React.useState(false); const [editItem, setEditItem] = React.useState(null);
  const { notification, showSuccess, showError } = useNotification();

  const handleSubmit = async (e) => {
    e.preventDefault(); if (!subjectCode || !subjectName || !credits || !deptId || !semester) { showError("Fill all fields"); return; }
    try {
      setSaving(true); const res = await authFetch(`${API_BASE}/admin/subjects`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ subject_code: subjectCode.toUpperCase(), subject_name: subjectName.trim(), credits: Number(credits), dept_id: Number(deptId), semester: Number(semester) }) });
      if (!res.ok) throw new Error(await res.text()); setSubjectCode(""); setSubjectName(""); setCredits(""); showSuccess("Created!"); refetch();
    } catch (e) { showError(e.message); } finally { setSaving(false); }
  };

  const handleDelete = async (code) => { if (!confirm("Delete?")) return; try { const res = await authFetch(`${API_BASE}/admin/subjects/${code}`, { method: "DELETE" }); if (!res.ok) throw new Error(await res.text()); showSuccess("Deleted"); refetch(); } catch (e) { showError(e.message); } };

  const handleEdit = async (data) => {
    try {
      const res = await authFetch(`${API_BASE}/admin/subjects/${editItem.subject_code}`, { method: "PUT", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ subject_name: data.subject_name, credits: Number(data.credits), dept_id: Number(data.dept_id), semester: Number(data.semester) }) });
      if (!res.ok) throw new Error(await res.text()); setEditItem(null); showSuccess("Updated!"); refetch();
    } catch (e) { showError(e.message); }
  };

  const deptById = Object.fromEntries(departments.map(d => [d.dept_id, d.dept_name]));

  return (
    <div className="card">
      <div className="card-header"><div><div className="card-title">Subjects</div><div className="card-subtitle">Define subjects</div></div></div>
      {notification && <div className={`alert alert-${notification.type}`}>{notification.message}</div>}
      <form onSubmit={handleSubmit}>
        <div className="form-grid">
          <div className="field"><label>Code</label><input value={subjectCode} onChange={e => setSubjectCode(e.target.value)} placeholder="CS201" /></div>
          <div className="field"><label>Name</label><input value={subjectName} onChange={e => setSubjectName(e.target.value)} placeholder="Data Structures" /></div>
          <div className="field"><label>Credits</label><input type="number" value={credits} onChange={e => setCredits(e.target.value)} placeholder="3" min="1" max="6" /></div>
          <div className="field"><label>Dept</label><select value={deptId} onChange={e => setDeptId(e.target.value)}><option value="">Select</option>{departments.map(d => <option key={d.dept_id} value={d.dept_id}>{d.dept_name}</option>)}</select></div>
          <div className="field"><label>Semester</label><select value={semester} onChange={e => setSemester(e.target.value)}><option value="">Select</option>{[1, 2, 3, 4, 5, 6, 7, 8].map(s => <option key={s} value={s}>Sem {s}</option>)}</select></div>
        </div>
        <button className="primary-button" disabled={saving}>{saving ? "Saving..." : "Add Subject"}</button>
      </form>
      <div className="status-bar">{loading ? "Loading..." : `${subjects.length} subjects`}</div>
      <table className="table"><thead><tr><th>Code</th><th>Name</th><th>Credits</th><th>Dept</th><th>Sem</th><th>Actions</th></tr></thead><tbody>
        {subjects.map(s => (<tr key={s.subject_code}><td><strong>{s.subject_code}</strong></td><td>{s.subject_name}</td><td>{s.credits}</td><td>{deptById[s.dept_id]}</td><td>Sem {s.semester}</td><td>
          <button className="secondary-button" onClick={() => setEditItem(s)}>Edit</button>
          <button className="danger-button" style={{ marginLeft: "8px" }} onClick={() => handleDelete(s.subject_code)}>Delete</button>
        </td></tr>))}
      </tbody></table>
      {editItem && <EditModal title="Edit Subject" fields={[{ name: "subject_name", label: "Name" }, { name: "credits", label: "Credits", type: "number" }, { name: "dept_id", label: "Dept", type: "select", options: departments.map(d => ({ value: d.dept_id, label: d.dept_name })) }, { name: "semester", label: "Semester", type: "select", options: [1, 2, 3, 4, 5, 6, 7, 8].map(s => ({ value: s, label: `Sem ${s}` })) }]} values={{ subject_name: editItem.subject_name, credits: editItem.credits, dept_id: editItem.dept_id, semester: editItem.semester }} onSave={handleEdit} onClose={() => setEditItem(null)} />}
    </div>
  );
}

// =============================================
// OTHER SECTIONS (Mappings, Face Enrollment)
// =============================================

function TeacherSubjectSection() {
  const { items: teachers } = useFetchList(`${API_BASE}/admin/teachers`);
  const { items: subjects } = useFetchList(`${API_BASE}/admin/subjects`);
  const { items: mappings, loading, refetch } = useFetchList(`${API_BASE}/admin/teacher-subjects`);
  const [teacherId, setTeacherId] = React.useState(""); const [subjectCode, setSubjectCode] = React.useState("");
  const [saving, setSaving] = React.useState(false);
  const { notification, showSuccess, showError } = useNotification();

  const handleSubmit = async (e) => {
    e.preventDefault(); if (!teacherId || !subjectCode) return;
    try {
      setSaving(true); const res = await authFetch(`${API_BASE}/admin/teacher-subjects`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ teacher_id: Number(teacherId), subject_code: subjectCode }) });
      if (!res.ok) throw new Error(await res.text()); showSuccess("Assigned!"); refetch();
    } catch (e) { showError(e.message); } finally { setSaving(false); }
  };

  const handleDelete = async (tid, sc) => { if (!confirm("Remove?")) return; try { const res = await authFetch(`${API_BASE}/admin/teacher-subjects/${tid}/${sc}`, { method: "DELETE" }); if (!res.ok) throw new Error(await res.text()); showSuccess("Removed"); refetch(); } catch (e) { showError(e.message); } };

  const teacherById = Object.fromEntries(teachers.map(t => [t.teacher_id, `${t.employee_no} - ${t.name || ''}`]));
  const subjectByCode = Object.fromEntries(subjects.map(s => [s.subject_code, s.subject_name]));

  return (
    <div className="card">
      <div className="card-header"><div><div className="card-title">Teacher-Subject Mapping</div></div></div>
      {notification && <div className={`alert alert-${notification.type}`}>{notification.message}</div>}
      <form onSubmit={handleSubmit}>
        <div className="form-grid">
          <div className="field"><label>Teacher</label><select value={teacherId} onChange={e => setTeacherId(e.target.value)}><option value="">Select</option>{teachers.map(t => <option key={t.teacher_id} value={t.teacher_id}>{t.employee_no} - {t.name}</option>)}</select></div>
          <div className="field"><label>Subject</label><select value={subjectCode} onChange={e => setSubjectCode(e.target.value)}><option value="">Select</option>{subjects.map(s => <option key={s.subject_code} value={s.subject_code}>{s.subject_code} - {s.subject_name}</option>)}</select></div>
        </div>
        <button className="primary-button" disabled={saving}>{saving ? "..." : "Assign"}</button>
      </form>
      <div className="status-bar">{loading ? "Loading..." : `${mappings.length} mappings`}</div>
      <table className="table"><thead><tr><th>Teacher</th><th>Subject</th><th>Actions</th></tr></thead><tbody>
        {mappings.map((m, i) => (<tr key={i}><td>{teacherById[m.teacher_id]}</td><td>{m.subject_code} - {subjectByCode[m.subject_code]}</td><td><button className="danger-button" onClick={() => handleDelete(m.teacher_id, m.subject_code)}>Delete</button></td></tr>))}
      </tbody></table>
    </div>
  );
}

function ClassSubjectSection() {
  const { items: classes } = useFetchList(`${API_BASE}/admin/classes`);
  const { items: subjects } = useFetchList(`${API_BASE}/admin/subjects`);
  const { items: mappings, loading, refetch } = useFetchList(`${API_BASE}/admin/class-subjects`);
  const [classId, setClassId] = React.useState(""); const [subjectCode, setSubjectCode] = React.useState("");
  const [saving, setSaving] = React.useState(false);
  const { notification, showSuccess, showError } = useNotification();

  const handleSubmit = async (e) => {
    e.preventDefault(); if (!classId || !subjectCode) return;
    try {
      setSaving(true); const res = await authFetch(`${API_BASE}/admin/class-subjects`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ class_id: classId, subject_code: subjectCode }) });
      if (!res.ok) throw new Error(await res.text()); showSuccess("Assigned to class!"); refetch();
    } catch (e) { showError(e.message); } finally { setSaving(false); }
  };

  const handleDelete = async (cn, sc) => { if (!confirm("Remove?")) return; try { const res = await authFetch(`${API_BASE}/admin/class-subjects/${cn}/${sc}`, { method: "DELETE" }); if (!res.ok) throw new Error(await res.text()); showSuccess("Removed"); refetch(); } catch (e) { showError(e.message); } };

  const classById = Object.fromEntries(classes.map(c => [c.class_id, `Class ${c.class_id} (Y${c.year}-${c.section})`]));
  const subjectByCode = Object.fromEntries(subjects.map(s => [s.subject_code, s.subject_name]));

  return (
    <div className="card">
      <div className="card-header"><div><div className="card-title">Class-Subject Mapping</div><div className="card-subtitle">Assign subjects to entire classes</div></div></div>
      {notification && <div className={`alert alert-${notification.type}`}>{notification.message}</div>}
      <div className="alert alert-info">💡 All students in the class will get this subject automatically</div>
      <form onSubmit={handleSubmit}>
        <div className="form-grid">
          <div className="field"><label>Class</label><select value={classId} onChange={e => setClassId(e.target.value)}><option value="">Select</option>{classes.map(c => <option key={c.class_id} value={c.class_id}>Class {c.class_id} (Y{c.year}-{c.section})</option>)}</select></div>
          <div className="field"><label>Subject</label><select value={subjectCode} onChange={e => setSubjectCode(e.target.value)}><option value="">Select</option>{subjects.map(s => <option key={s.subject_code} value={s.subject_code}>{s.subject_code} - {s.subject_name}</option>)}</select></div>
        </div>
        <button className="primary-button" disabled={saving}>{saving ? "..." : "Assign to Class"}</button>
      </form>
      <div className="status-bar">{loading ? "Loading..." : `${mappings.length} mappings`}</div>
      <table className="table"><thead><tr><th>Class</th><th>Subject</th><th>Actions</th></tr></thead><tbody>
        {mappings.map((m, i) => (<tr key={i}><td><strong>{classById[m.class_id]}</strong></td><td>{m.subject_code} - {subjectByCode[m.subject_code]}</td><td><button className="danger-button" onClick={() => handleDelete(m.class_id, m.subject_code)}>Delete</button></td></tr>))}
      </tbody></table>
    </div>
  );
}

function FaceEnrollmentSection() {
  const { items: students } = useFetchList(`${API_BASE}/admin/students`);
  const { items: profiles, loading, refetch } = useFetchList(`${API_BASE}/admin/faces/profiles`);
  const [regNo, setRegNo] = React.useState(""); const [file, setFile] = React.useState(null);
  const [saving, setSaving] = React.useState(false);
  const { notification, showSuccess, showError } = useNotification();

  const handleSubmit = async (e) => {
    e.preventDefault(); if (!regNo || !file) { showError("Select student and image"); return; }
    try {
      setSaving(true); const fd = new FormData(); fd.append("reg_no", regNo); fd.append("image", file);
      const res = await authFetch(`${API_BASE}/admin/faces/enroll`, { method: "POST", body: fd });
      if (!res.ok) throw new Error(await res.text()); showSuccess("Face enrolled!"); setFile(null); refetch();
    } catch (e) { showError(e.message); } finally { setSaving(false); }
  };

  const handleDelete = async (rn) => { if (!confirm(`Delete face for ${rn}?`)) return; try { const res = await authFetch(`${API_BASE}/admin/faces/${rn}`, { method: "DELETE" }); if (!res.ok) throw new Error(await res.text()); showSuccess("Deleted"); refetch(); } catch (e) { showError(e.message); } };

  const studentByReg = Object.fromEntries(students.map(s => [s.reg_no, s.name]));
  const enrolledRegs = new Set(profiles.filter(p => p.has_embedding).map(p => p.reg_no));

  return (
    <div className="card">
      <div className="card-header"><div><div className="card-title">Face Enrollment</div><div className="card-subtitle">Upload face images for AI attendance</div></div></div>
      {notification && <div className={`alert alert-${notification.type}`}>{notification.message}</div>}
      <div className="stats-grid"><div className="stat-card"><div className="stat-value">{profiles.length}</div><div className="stat-label">Enrolled</div></div><div className="stat-card"><div className="stat-value">{students.length - profiles.length}</div><div className="stat-label">Pending</div></div></div>
      <form onSubmit={handleSubmit}>
        <div className="form-grid">
          <div className="field"><label>Student</label><select value={regNo} onChange={e => setRegNo(e.target.value)}><option value="">Select</option>{students.map(s => <option key={s.reg_no} value={s.reg_no}>{enrolledRegs.has(s.reg_no) ? "✓ " : ""}{s.reg_no} - {s.name}</option>)}</select></div>
          <div className="field"><label>Face Image</label><input type="file" accept="image/*" onChange={e => setFile(e.target.files[0])} /></div>
        </div>
        <button className="primary-button" disabled={saving}>{saving ? "Processing..." : "Enroll Face"}</button>
      </form>
      <div className="status-bar">{loading ? "Loading..." : `${profiles.length} profiles`}</div>
      <table className="table"><thead><tr><th>Reg No</th><th>Name</th><th>Status</th><th>Actions</th></tr></thead><tbody>
        {profiles.map(p => (<tr key={p.face_id}><td><strong>{p.reg_no}</strong></td><td>{studentByReg[p.reg_no]}</td><td>{p.has_embedding ? <span className="badge badge-success">Enrolled</span> : <span className="badge badge-warning">Pending</span>}</td><td><button className="danger-button" onClick={() => handleDelete(p.reg_no)}>Delete</button></td></tr>))}
      </tbody></table>
    </div>
  );
}

// =============================================
// MARKS CONFIG SECTION
// =============================================

function MarksConfigSection() {
  const { items: subjects } = useFetchList(`${API_BASE}/admin/subjects`);
  const { items: configs, loading: listLoading, error: listError, refetch } = useFetchList(`${API_BASE}/marks/configs`);
  const [selectedSubject, setSelectedSubject] = React.useState("");
  const [internalWeight, setInternalWeight] = React.useState(40);
  const [externalWeight, setExternalWeight] = React.useState(60);
  const [hasLab, setHasLab] = React.useState(false);
  const [isPurePractical, setIsPurePractical] = React.useState(false);

  const [loading, setLoading] = React.useState(false);
  const { notification, showSuccess, showError } = useNotification();

  // Load existing config when subject is selected
  console.log("MarksConfigSection Render", { configs, listLoading, subjects, error: listError });

  React.useEffect(() => {
    if (!selectedSubject) return;

    // 1. Try to find in the already fetched list to save bandwidth/latency
    const found = configs.find(c => c.subject_code === selectedSubject);
    if (found) {
      setInternalWeight(found.internal_weight);
      setExternalWeight(found.external_weight);
      setHasLab(found.has_lab);
      setIsPurePractical(found.is_pure_practical);
      return;
    }

    // 2. If not found (maybe fresher?), fetch individual
    const fetchConfig = async () => {
      try {
        setLoading(true);
        const res = await authFetch(`${API_BASE}/marks/config/${selectedSubject}`);
        if (res.ok) {
          const data = await res.json();
          setInternalWeight(data.internal_weight);
          setExternalWeight(data.external_weight);
          setHasLab(data.has_lab);
          setIsPurePractical(data.is_pure_practical);
        }
      } catch (e) {
        // Defaults
        setInternalWeight(40);
        setExternalWeight(60);
        setHasLab(false);
        setIsPurePractical(false);
      } finally {
        setLoading(false);
      }
    };

    fetchConfig();
  }, [selectedSubject, configs]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!selectedSubject) { showError("Select a subject"); return; }

    // Validation
    if (Number(internalWeight) + Number(externalWeight) !== 100) {
      showError("Weights must sum to 100");
      return;
    }

    try {
      setLoading(true);
      const payload = {
        subject_code: selectedSubject,
        internal_weight: Number(internalWeight),
        external_weight: Number(externalWeight),
        has_lab: hasLab,
        is_pure_practical: isPurePractical
      };

      const res = await authFetch(`${API_BASE}/marks/config`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload)
      });

      if (!res.ok) throw new Error(await res.text());
      showSuccess("Configuration Saved!");
      refetch();
    } catch (e) {
      showError(e.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="card">
      <div className="card-header">
        <div>
          <div className="card-title">Marks Configuration</div>
          <div className="card-subtitle">Set grading weights for subjects</div>
        </div>
      </div>

      {notification && <div className={`alert alert-${notification.type}`}>{notification.message}</div>}

      <form onSubmit={handleSubmit}>
        <div className="form-grid">
          <div className="field">
            <label>Subject</label>
            <select value={selectedSubject} onChange={e => setSelectedSubject(e.target.value)}>
              <option value="">Select Subject</option>
              {subjects.map(s => <option key={s.subject_code} value={s.subject_code}>{s.subject_code} - {s.subject_name}</option>)}
            </select>
          </div>

          <div className="field">
            <label>Internal Weight (%)</label>
            <select value={internalWeight} onChange={e => {
              const val = Number(e.target.value);
              setInternalWeight(val);
              setExternalWeight(100 - val);
            }}>
              <option value={40}>40% (Standard)</option>
              <option value={50}>50% (Lab Integrated)</option>
              <option value={0}>0% (External Only)</option>
              <option value={100}>100% (Internal Only)</option>
            </select>
          </div>

          <div className="field">
            <label>External Weight (%)</label>
            <input type="number" value={externalWeight} disabled readOnly />
          </div>

          <div className="field" style={{ display: 'flex', alignItems: 'center', gap: '10px', marginTop: '25px' }}>
            <input type="checkbox" id="hasLab" checked={hasLab} onChange={e => setHasLab(e.target.checked)} />
            <label htmlFor="hasLab" style={{ margin: 0 }}>Has Lab Component?</label>
          </div>

          <div className="field" style={{ display: 'flex', alignItems: 'center', gap: '10px', marginTop: '25px' }}>
            <input type="checkbox" id="isPractical" checked={isPurePractical} onChange={e => setIsPurePractical(e.target.checked)} />
            <label htmlFor="isPractical" style={{ margin: 0 }}>Is Pure Practical?</label>
          </div>
        </div>

        <button className="primary-button" disabled={loading}>
          {loading ? "Saving..." : "Save Configuration"}
        </button>
      </form>

      <div className="status-bar">
        {listLoading ? "Loading..." : `${configs.length} configured subjects`}
        {listError && <span style={{ color: 'red', marginLeft: '10px' }}>Error: {listError}</span>}
      </div>
      <table className="table">
        <thead>
          <tr>
            <th>Subject</th>
            <th>Internal</th>
            <th>External</th>
            <th>Mode</th>
            <th>Action</th>
          </tr>
        </thead>
        <tbody>
          {configs.map(c => (
            <tr key={c.config_id}>
              <td><strong>{c.subject_code}</strong></td>
              <td>{c.internal_weight}%</td>
              <td>{c.external_weight}%</td>
              <td>
                {c.is_pure_practical ? <span className="badge badge-warning">Practical</span> :
                  c.has_lab ? <span className="badge badge-info">Theory+Lab</span> : "Theory"}
              </td>
              <td>
                <button className="secondary-button" onClick={() => setSelectedSubject(c.subject_code)}>Edit</button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

// =============================================
// STUDENT PROFILE SECTION
// =============================================
function StudentProfileSection() {
  const { items: classes } = useFetchList(`${API_BASE}/admin/classes`);
  const [selectedClass, setSelectedClass] = React.useState("");
  const [students, setStudents] = React.useState([]);
  const [selectedStudent, setSelectedStudent] = React.useState("");
  const [loading, setLoading] = React.useState(false);
  const { notification, showSuccess, showError } = useNotification();

  // Form State
  const [formData, setFormData] = React.useState({
    personal_email: "",
    student_mobile: "",
    father_mobile: "",
    mother_mobile: "",
    address: "",
    state: "",
    tenth_mark: "",
    twelfth_mark: ""
  });

  // Fetch Students when Class Changes
  React.useEffect(() => {
    if (!selectedClass) { setStudents([]); return; }
    const fetchStudents = async () => {
      try {
        const res = await authFetch(`${API_BASE}/admin/students?class_id=${selectedClass}`);
        if (res.ok) setStudents(await res.json());
      } catch (e) { console.error(e); }
    };
    fetchStudents();
  }, [selectedClass]);

  // Fetch Profile when Student Changes
  React.useEffect(() => {
    if (!selectedStudent) {
      setFormData({ personal_email: "", student_mobile: "", father_mobile: "", mother_mobile: "", address: "", state: "", tenth_mark: "", twelfth_mark: "" });
      return;
    }
    const fetchProfile = async () => {
      try {
        setLoading(true);
        const res = await authFetch(`${API_BASE}/profiles/${selectedStudent}`);
        if (res.ok) {
          const data = await res.json();
          // Only fill if data exists, else defaults
          setFormData({
            personal_email: data.personal_email || "",
            student_mobile: data.student_mobile || "",
            father_mobile: data.father_mobile || "",
            mother_mobile: data.mother_mobile || "",
            address: data.address || "",
            state: data.state || "",
            tenth_mark: data.tenth_mark || "",
            twelfth_mark: data.twelfth_mark || ""
          });
        }
      } catch (e) {
        console.error(e);
      } finally {
        setLoading(false);
      }
    };
    fetchProfile();
  }, [selectedStudent]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!selectedStudent) { showError("Select a student"); return; }

    try {
      setLoading(true);
      const payload = {
        student_id: Number(selectedStudent),
        ...formData
      };

      const res = await authFetch(`${API_BASE}/profiles/`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload)
      });

      if (!res.ok) throw new Error(await res.text());
      showSuccess("Profile Updated Successfully!");
    } catch (e) {
      showError(e.message);
    } finally {
      setLoading(false);
    }
  };

  const handleChange = (e) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
  };

  return (
    <div className="card">
      <div className="card-header">
        <div className="card-title">Student Profiles</div>
        <div className="card-subtitle">Manage personal details</div>
      </div>

      {notification && <div className={`alert alert-${notification.type}`}>{notification.message}</div>}

      <div className="form-grid" style={{ marginBottom: '20px', borderBottom: '1px solid #eee', paddingBottom: '20px' }}>
        <div className="field">
          <label>Select Class</label>
          <select value={selectedClass} onChange={e => setSelectedClass(e.target.value)}>
            <option value="">-- Class --</option>
            {classes.map(c => <option key={c.class_id} value={c.class_id}>{c.dept_name} {c.year}-{c.section}</option>)}
          </select>
        </div>
        <div className="field">
          <label>Select Student</label>
          <select value={selectedStudent} onChange={e => setSelectedStudent(e.target.value)} disabled={!selectedClass}>
            <option value="">-- Student --</option>
            {students.map(s => <option key={s.student_id} value={s.student_id}>{s.reg_no} - {s.name}</option>)}
          </select>
        </div>
      </div>

      {selectedStudent && (
        <form onSubmit={handleSubmit}>
          <div className="form-grid">
            <div className="field">
              <label>Personal Email</label>
              <input name="personal_email" value={formData.personal_email} onChange={handleChange} type="email" />
            </div>
            <div className="field">
              <label>Student Mobile</label>
              <input name="student_mobile" value={formData.student_mobile} onChange={handleChange} />
            </div>
            <div className="field">
              <label>Father Mobile</label>
              <input name="father_mobile" value={formData.father_mobile} onChange={handleChange} />
            </div>
            <div className="field">
              <label>Mother Mobile</label>
              <input name="mother_mobile" value={formData.mother_mobile} onChange={handleChange} />
            </div>
            <div className="field">
              <label>Address</label>
              <textarea name="address" value={formData.address} onChange={handleChange} rows="3" />
            </div>
            <div className="field">
              <label>State</label>
              <input name="state" value={formData.state} onChange={handleChange} />
            </div>
            <div className="field">
              <label>10th Mark</label>
              <input name="tenth_mark" value={formData.tenth_mark} onChange={handleChange} />
            </div>
            <div className="field">
              <label>12th Mark</label>
              <input name="twelfth_mark" value={formData.twelfth_mark} onChange={handleChange} />
            </div>
          </div>

          <button className="primary-button" disabled={loading}>
            {loading ? "Saving..." : "Save Profile"}
          </button>
        </form>
      )}
    </div>
  );
}

// =============================================
// ATTENDANCE SECTION
// =============================================

function AttendanceSection() {
  const { items: departments } = useFetchList(`${API_BASE}/admin/departments`);
  const { items: allClasses } = useFetchList(`${API_BASE}/admin/classes`);

  const [selectedDept, setSelectedDept] = React.useState("");
  const [selectedClass, setSelectedClass] = React.useState("");
  const [students, setStudents] = React.useState([]);
  const [selectedStudent, setSelectedStudent] = React.useState("");
  const [studentDetails, setStudentDetails] = React.useState(null);

  const [attendance, setAttendance] = React.useState([]);
  const [loading, setLoading] = React.useState(false);

  // Edit State
  const [editRecord, setEditRecord] = React.useState(null);
  const [newStatus, setNewStatus] = React.useState("P");

  const [dateRange, setDateRange] = React.useState({ start: "", end: "" });

  const { showSuccess, showError } = useNotification();

  // Filter Classes by Dept
  const filteredClasses = React.useMemo(() => {
    if (!selectedDept) return [];
    return allClasses.filter(c => c.dept_id === Number(selectedDept));
  }, [allClasses, selectedDept]);

  // Load Students
  React.useEffect(() => {
    if (!selectedClass) { setStudents([]); return; }
    authFetch(`${API_BASE}/admin/students?class_id=${selectedClass}`)
      .then(res => res.json())
      .then(data => setStudents(data))
      .catch(console.error);
  }, [selectedClass]);

  // Load Attendance & Profile
  const fetchAttendance = React.useCallback(async () => {
    if (!selectedStudent) { setAttendance([]); setStudentDetails(null); return; }
    setLoading(true);
    try {
      // Fetch Attendance
      const attRes = await authFetch(`${API_BASE}/admin/attendance/records/${selectedStudent}`);
      if (attRes.ok) setAttendance(await attRes.json());

      // Fetch Profile (separate try/catch so one fails doesn't block other)
      try {
        const profRes = await authFetch(`${API_BASE}/profiles/${selectedStudent}`);
        if (profRes.ok) setStudentDetails(await profRes.json());
      } catch (e) { console.log("Profile not found"); }

    } catch (e) { console.error(e); }
    finally { setLoading(false); }
  }, [selectedStudent]);

  React.useEffect(() => {
    fetchAttendance();
  }, [fetchAttendance]);


  // Helper: Filter by Date
  const filteredAttendance = React.useMemo(() => {
    return attendance.filter(r => {
      if (dateRange.start && r.date < dateRange.start) return false;
      if (dateRange.end && r.date > dateRange.end) return false;
      return true;
    });
  }, [attendance, dateRange]);

  // Helper: Stats
  const stats = React.useMemo(() => {
    const total = filteredAttendance.length;
    const present = filteredAttendance.filter(r => r.status === 'P').length;
    const absent = filteredAttendance.filter(r => r.status === 'A').length;
    const od = filteredAttendance.filter(r => r.status === 'OD').length;
    const ml = filteredAttendance.filter(r => r.status === 'ML').length;
    const percentage = total > 0 ? ((present + od) / total * 100).toFixed(2) : 0;
    return { total, present, absent, od, ml, percentage };
  }, [filteredAttendance]);

  // Helper: Grid Data
  const gridData = React.useMemo(() => {
    const grouped = {};
    filteredAttendance.forEach(r => {
      if (!grouped[r.date]) {
        const d = new Date(r.date);
        const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
        grouped[r.date] = {
          date: r.date,
          day: days[d.getDay()],
          periods: {}
        };
      }
      grouped[r.date].periods[r.period] = r;
    });
    return Object.values(grouped).sort((a, b) => new Date(b.date) - new Date(a.date));
  }, [filteredAttendance]);


  const handleSaveEdit = async () => {
    if (!editRecord) return;
    try {
      const res = await authFetch(`${API_BASE}/admin/attendance/record`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ attendance_id: editRecord.attendance_id, status: newStatus })
      });

      if (!res.ok) {
        const txt = await res.text();
        throw new Error("Failed to update: " + txt);
      }

      showSuccess("Updated Status");
      setEditRecord(null);
      // Manually update local state to avoid full reload delay
      setAttendance(prev => prev.map(p =>
        p.attendance_id === editRecord.attendance_id ? { ...p, status: newStatus } : p
      ));

    } catch (e) {
      showError(e.message);
    }
  };

  const getCellClass = (status) => {
    switch (status) {
      case "P": return "status-p";
      case "A": return "status-a";
      case "OD": return "status-od";
      case "ML": return "status-ml";
      default: return "";
    }
  };

  return (
    <div className="card" style={{ maxWidth: '1200px', margin: '0 auto', border: '1px solid #3a3a5c' }}>

      {/* 1. Header & Filters */}
      <div className="report-header" style={{ marginBottom: '20px', borderBottom: '1px solid #3a3a5c', paddingBottom: '20px' }}>
        <div style={{ textAlign: 'center', marginBottom: '20px' }}>
          <h2 style={{ color: '#a78bfa', margin: 0, fontSize: '1.5rem', fontWeight: 'bold' }}>Hindusthan College of Engineering and Technology</h2>
          <div style={{ color: '#94a3b8' }}>Student Attendance Report</div>
        </div>

        <div className="form-grid">
          <div className="field">
            <label>Department</label>
            <select value={selectedDept} onChange={e => { setSelectedDept(e.target.value); setSelectedClass(""); }}>
              <option value="">-- Select Department --</option>
              {departments.map(d => <option key={d.dept_id} value={d.dept_id}>{d.dept_name}</option>)}
            </select>
          </div>
          <div className="field">
            <label>Class</label>
            <select value={selectedClass} onChange={e => setSelectedClass(e.target.value)} disabled={!selectedDept}>
              <option value="">-- Select Class --</option>
              {filteredClasses.map(c => <option key={c.class_id} value={c.class_id}>{c.class_id} ({c.year}-{c.section})</option>)}
            </select>
          </div>
          <div className="field">
            <label>Student</label>
            <select value={selectedStudent} onChange={e => setSelectedStudent(e.target.value)} disabled={!selectedClass}>
              <option value="">-- Select Student --</option>
              {students.map(s => <option key={s.reg_no} value={s.reg_no}>{s.reg_no} - {s.name}</option>)}
            </select>
          </div>
          <div className="field">
            <label>From Date</label>
            <input type="date" value={dateRange.start} onChange={e => setDateRange({ ...dateRange, start: e.target.value })} />
          </div>
          <div className="field">
            <label>To Date</label>
            <input type="date" value={dateRange.end} onChange={e => setDateRange({ ...dateRange, end: e.target.value })} />
          </div>
        </div>
      </div>

      {loading && <div style={{ textAlign: 'center', padding: '20px', color: '#94a3b8' }}>Loading records...</div>}

      {/* 2. Stats Panel & Student Info */}
      {!loading && selectedStudent && (
        <div style={{ display: 'flex', gap: '20px', marginBottom: '20px', flexWrap: 'wrap' }}>
          {/* Profile Box */}
          <div style={{ flex: '1', background: '#1e1e32', padding: '15px', borderRadius: '8px', minWidth: '250px', border: '1px solid #3a3a5c' }}>
            <div style={{ fontWeight: 'bold', marginBottom: '10px', borderBottom: '1px solid #3a3a5c', color: '#a78bfa' }}>Student Details</div>
            <div style={{ display: 'grid', gridTemplateColumns: 'auto 1fr', gap: '10px', fontSize: '14px', color: '#e2e8f0' }}>
              <div>Name:</div><div style={{ fontWeight: '600' }}>{studentDetails?.name || students.find(s => s.reg_no === selectedStudent)?.name || '-'}</div>
              <div>Reg No:</div><div style={{ fontWeight: '600' }}>{selectedStudent}</div>
              <div>Class:</div><div>{selectedClass}</div>
            </div>
          </div>

          {/* Stats Box */}
          <div style={{ flex: '2', display: 'flex', gap: '15px', justifyContent: 'space-around', alignItems: 'center', background: '#141423', padding: '15px', borderRadius: '8px', border: '1px solid #3a3a5c' }}>
            <div style={{ textAlign: 'center' }}>
              <div style={{ fontSize: '24px', fontWeight: 'bold', color: '#6366f1' }}>{stats.percentage}%</div>
              <div style={{ fontSize: '12px', color: '#94a3b8' }}>Attendance</div>
            </div>
            <div style={{ height: '40px', width: '1px', background: '#3a3a5c' }}></div>
            <div style={{ textAlign: 'center' }}>
              <div style={{ fontSize: '18px', fontWeight: 'bold', color: '#e2e8f0' }}>{stats.total}</div>
              <div style={{ fontSize: '12px', color: '#94a3b8' }}>Total Hrs</div>
            </div>
            <div style={{ textAlign: 'center' }}>
              <div style={{ fontSize: '18px', fontWeight: 'bold', color: '#22c55e' }}>{stats.present}</div>
              <div style={{ fontSize: '12px', color: '#94a3b8' }}>Present</div>
            </div>
            <div style={{ textAlign: 'center' }}>
              <div style={{ fontSize: '18px', fontWeight: 'bold', color: '#ef4444' }}>{stats.absent}</div>
              <div style={{ fontSize: '12px', color: '#94a3b8' }}>Absent</div>
            </div>
            <div style={{ textAlign: 'center' }}>
              <div style={{ fontSize: '18px', fontWeight: 'bold', color: '#f59e0b' }}>{stats.od}</div>
              <div style={{ fontSize: '12px', color: '#94a3b8' }}>OD</div>
            </div>
          </div>
        </div>
      )}

      {/* 3. Grid Table */}
      {!loading && selectedStudent && (
        <div style={{ overflowX: 'auto' }}>
          <table className="table" style={{ width: '100%', borderCollapse: 'separate', borderSpacing: '0' }}>
            <thead>
              <tr style={{ background: '#1e1e32' }}>
                <th style={{ padding: '10px', color: '#94a3b8', borderBottom: '1px solid #3a3a5c' }}>Date</th>
                <th style={{ padding: '10px', color: '#94a3b8', borderBottom: '1px solid #3a3a5c' }}>Day</th>
                {[1, 2, 3, 4, 5, 6, 7].map(p => <th key={p} style={{ padding: '10px', color: '#94a3b8', borderBottom: '1px solid #3a3a5c', textAlign: 'center' }}>{p}</th>)}
              </tr>
            </thead>
            <tbody>
              {gridData.map(row => (
                <tr key={row.date} style={{ borderBottom: '1px solid #3a3a5c' }}>
                  <td style={{ padding: '8px', color: '#e2e8f0', borderBottom: '1px solid #3a3a5c' }}>{row.date}</td>
                  <td style={{ padding: '8px', color: '#e2e8f0', borderBottom: '1px solid #3a3a5c' }}>{row.day}</td>
                  {[1, 2, 3, 4, 5, 6, 7].map(p => {
                    const rec = row.periods[p];
                    return (
                      <td key={p}
                        onClick={() => {
                          if (rec) {
                            setEditRecord(rec);
                            setNewStatus(rec.status);
                          } else {
                            showError("No attendance record found for this period. Cannot edit.");
                          }
                        }}
                        style={{
                          padding: '8px',
                          textAlign: 'center',
                          cursor: rec ? 'pointer' : 'not-allowed',
                          fontWeight: 'bold',
                          borderBottom: '1px solid #3a3a5c',
                          background: rec ? (rec.status === 'P' ? 'rgba(34, 197, 94, 0.1)' : rec.status === 'A' ? 'rgba(239, 68, 68, 0.1)' : rec.status === 'OD' ? 'rgba(245, 158, 11, 0.1)' : 'rgba(99, 102, 241, 0.1)') : 'transparent',
                          color: rec ? (rec.status === 'P' ? '#22c55e' : rec.status === 'A' ? '#ef4444' : rec.status === 'OD' ? '#f59e0b' : '#6366f1') : '#3a3a5c'
                        }}
                      >
                        {rec ? rec.status : '-'}
                      </td>
                    );
                  })}
                </tr>
              ))}
              {gridData.length === 0 && <tr><td colSpan="9" style={{ textAlign: 'center', padding: '20px', color: '#64748b' }}>No records found within this range.</td></tr>}
            </tbody>
          </table>
        </div>
      )}

      {/* Edit Modal */}
      {editRecord && (
        <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(0,0,0,0.8)', display: 'flex', justifyContent: 'center', alignItems: 'center', zIndex: 1000 }}>
          <div className="card" style={{ width: '350px', border: '1px solid #3a3a5c', background: '#1e1e32' }}>
            <h3 style={{ color: '#a78bfa', marginBottom: '10px' }}>Edit Attendance</h3>
            <p style={{ color: '#e2e8f0', fontSize: '0.9rem', marginBottom: '5px' }}>Date: {editRecord.date} | Period: {editRecord.period}</p>
            <p style={{ color: '#94a3b8', fontSize: '0.85rem' }}>Subject: {editRecord.subject_code}</p>

            <div style={{ margin: '20px 0' }}>
              <label style={{ color: '#94a3b8', marginBottom: '5px', display: 'block' }}>Status:</label>
              <select value={newStatus} onChange={e => setNewStatus(e.target.value)} style={{ width: '100%', padding: '10px', background: '#141423', color: '#fff', border: '1px solid #3a3a5c', borderRadius: '5px' }}>
                <option value="P">Present (P)</option>
                <option value="A">Absent (A)</option>
                <option value="OD">On Duty (OD)</option>
                <option value="ML">Medical Leave (ML)</option>
                <option value="NT">Not Taken (NT)</option>
              </select>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px' }}>
              <button className="secondary-button" onClick={() => setEditRecord(null)}>Cancel</button>
              <button className="primary-button" onClick={handleSaveEdit}>Save</button>
            </div>
          </div>
        </div>
      )}

    </div>
  );
}

// =============================================
// USERS SECTION (Manage Credentials)
// =============================================

function UsersSection() {
  const { items: departments } = useFetchList(`${API_BASE}/admin/departments`);
  const { items: classes } = useFetchList(`${API_BASE}/admin/classes`);

  // Filters
  const [role, setRole] = React.useState("student"); // Default to student
  const [selectedDept, setSelectedDept] = React.useState("");
  const [selectedClass, setSelectedClass] = React.useState("");

  // Data
  const [users, setUsers] = React.useState([]);
  const [loading, setLoading] = React.useState(false);
  const { notification, showSuccess, showError } = useNotification();

  // Edit State
  const [editUser, setEditUser] = React.useState(null);
  const [newEmail, setNewEmail] = React.useState("");
  const [newPassword, setNewPassword] = React.useState("");
  const [saving, setSaving] = React.useState(false);

  // Fetch Users
  const fetchUsers = React.useCallback(async () => {
    setLoading(true);
    try {
      let url = `${API_BASE}/admin/users?role=${role}`;
      if (role === "student") {
        if (selectedClass) url += `&class_id=${selectedClass}`;
        if (selectedDept && !selectedClass) url += `&dept_id=${Number(selectedDept)}`;
      } else if (role === "teacher") {
        if (selectedDept) url += `&dept_id=${Number(selectedDept)}`;
      }

      const res = await authFetch(url);
      if (res.ok) {
        setUsers(await res.json());
      } else {
        throw new Error(await res.text());
      }
    } catch (e) {
      console.error(e);
      showError("Failed to fetch users");
    } finally {
      setLoading(false);
    }
  }, [role, selectedDept, selectedClass]);

  React.useEffect(() => {
    fetchUsers();
  }, [fetchUsers]);

  // Handle Edit Click
  const handleEditClick = (u) => {
    setEditUser(u);
    setNewEmail(u.email);
    setNewPassword(""); // Blank by default
  };

  // Save Credentials
  const handleSave = async (e) => {
    e.preventDefault();
    if (!newEmail) { showError("Email is required"); return; }

    try {
      setSaving(true);
      const payload = { email: newEmail };
      if (newPassword) payload.password = newPassword;

      const res = await authFetch(`${API_BASE}/admin/users/${editUser.user_id}/credentials`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload)
      });

      if (!res.ok) throw new Error(await res.text());

      showSuccess("Credentials Updated!");
      setEditUser(null);
      fetchUsers(); // Refresh

    } catch (e) {
      showError(e.message);
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="card">
      <div className="card-header">
        <div>
          <div className="card-title">User Management</div>
          <div className="card-subtitle">Manage login credentials</div>
        </div>
      </div>

      {notification && <div className={`alert alert-${notification.type}`}>{notification.message}</div>}

      {/* Filters */}
      <div className="form-grid" style={{ marginBottom: "20px", borderBottom: '1px solid rgba(255,255,255,0.1)', paddingBottom: '20px' }}>
        <div className="field">
          <label>Role</label>
          <select value={role} onChange={e => setRole(e.target.value)}>
            <option value="student">Student</option>
            <option value="teacher">Teacher</option>
            <option value="admin">Admin</option>
          </select>
        </div>

        {role === "student" && (
          <>
            <div className="field">
              <label>Department</label>
              <select value={selectedDept} onChange={e => { setSelectedDept(e.target.value); setSelectedClass(""); }}>
                <option value="">All Departments</option>
                {departments.map(d => <option key={d.dept_id} value={d.dept_id}>{d.dept_name}</option>)}
              </select>
            </div>
            <div className="field">
              <label>Class</label>
              <select value={selectedClass} onChange={e => setSelectedClass(e.target.value)}>
                <option value="">All Classes</option>
                {classes
                  .filter(c => !selectedDept || c.dept_id === Number(selectedDept))
                  .map(c => <option key={c.class_id} value={c.class_id}>{c.class_id} ({c.year}-{c.section})</option>)
                }
              </select>
            </div>
          </>
        )}

        {role === "teacher" && (
          <div className="field">
            <label>Department</label>
            <select value={selectedDept} onChange={e => setSelectedDept(e.target.value)}>
              <option value="">All Departments</option>
              {departments.map(d => <option key={d.dept_id} value={d.dept_id}>{d.dept_name}</option>)}
            </select>
          </div>
        )}
      </div>

      {/* Table */}
      <div className="status-bar">{loading ? "Loading..." : `${users.length} users found`}</div>
      <table className="table">
        <thead>
          <tr>
            <th>ID</th>
            <th>Name</th>
            <th>{role === 'student' ? 'Reg No' : role === 'teacher' ? 'Emp No' : 'Role'}</th>
            {role === 'student' && <th>Class</th>}
            <th>Email</th>
            <th>Status</th>
            <th>Action</th>
          </tr>
        </thead>
        <tbody>
          {users.map(u => (
            <tr key={u.user_id}>
              <td>{u.user_id}</td>
              <td><strong>{u.name || '-'}</strong></td>
              <td>{u.identifier || u.role}</td>
              {role === 'student' && <td>{u.class_id || '-'}</td>}
              <td>{u.email}</td>
              <td>
                <span className={`badge ${u.status === 'active' ? 'badge-success' : 'badge-warning'}`}>{u.status}</span>
              </td>
              <td>
                <button className="primary-button" style={{ fontSize: '0.8rem', padding: '6px 12px' }} onClick={() => handleEditClick(u)}>Edit Credentials</button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>

      {/* Edit Modal */}
      {editUser && (
        <div style={{ position: "fixed", top: 0, left: 0, right: 0, bottom: 0, background: "rgba(0,0,0,0.8)", display: "flex", alignItems: "center", justifyContent: "center", zIndex: 1000 }}>
          <div className="card" style={{ maxWidth: "400px", width: "90%" }}>
            <div className="card-header">
              <div className="card-title">Edit Credentials</div>
              <div className="card-subtitle">For {editUser.name || editUser.email}</div>
            </div>

            <form onSubmit={handleSave}>
              <div className="field">
                <label>Email</label>
                <input type="email" value={newEmail} onChange={e => setNewEmail(e.target.value)} required />
              </div>
              <div className="field" style={{ marginTop: "15px" }}>
                <label>New Password (Optional)</label>
                <input type="password" value={newPassword} onChange={e => setNewPassword(e.target.value)} placeholder="Leave blank to keep current" />
                <div style={{ fontSize: '0.8rem', color: '#64748b', marginTop: '5px' }}>Enter new password to overwrite.</div>
              </div>

              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px', marginTop: '20px' }}>
                <button type="button" className="secondary-button" onClick={() => setEditUser(null)}>Cancel</button>
                <button type="submit" className="primary-button" disabled={saving}>{saving ? "Saving..." : "Save Changes"}</button>
              </div>
            </form>
          </div>
        </div>
      )}

    </div>
  );
}

// =============================================
// LOGIN SCREEN
// =============================================

function LoginScreen({ onLogin }) {
  const [email, setEmail] = React.useState("");
  const [password, setPassword] = React.useState("");
  const [error, setError] = React.useState(null);
  const [loading, setLoading] = React.useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!email || !password) return;
    try {
      setLoading(true);
      setError(null);
      const res = await fetch(`${API_BASE}/auth/login`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password })
      });

      const data = await res.json();

      if (!res.ok) throw new Error(data.detail || "Login failed");

      if (data.role !== "admin") {
        throw new Error("Access denied: Not an administrator");
      }

      localStorage.setItem("admin_token", data.access_token);
      localStorage.setItem("admin_email", data.email);
      onLogin();
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ display: "flex", justifyContent: "center", alignItems: "center", minHeight: "100vh", background: "#0f0f1a" }}>
      <div className="card" style={{ maxWidth: "400px", width: "90%", padding: "40px" }}>
        <div style={{ textAlign: "center", marginBottom: "32px" }}>
          <h1 style={{ fontSize: "24px", color: "#ffffffff", marginBottom: "8px" }}>Admin Portal</h1>
          <p style={{ color: "#666666ff" }}>Please sign in to continue</p>
        </div>

        {error && <div className="alert alert-error" style={{ marginBottom: "20px" }}>{error}</div>}

        <form onSubmit={handleSubmit}>
          <div className="field">
            <label>Email</label>
            <input type="email" value={email} onChange={e => setEmail(e.target.value)} placeholder="admin@example.com" autoFocus />
          </div>
          <div className="field" style={{ marginTop: "16px" }}>
            <label>Password</label>
            <input type="password" value={password} onChange={e => setPassword(e.target.value)} placeholder="••••••" />
          </div>
          <button className="primary-button" style={{ width: "100%", marginTop: "24px", padding: "12px" }} disabled={loading}>
            {loading ? "Signing in..." : "Sign In"}
          </button>
        </form>
      </div>
    </div>
  );
}

// =============================================
// MAIN APP
// =============================================

function App() {
  const [section, setSection] = React.useState("departments");
  const [isLoggedIn, setIsLoggedIn] = React.useState(!!localStorage.getItem("admin_token"));

  if (!isLoggedIn) {
    return <LoginScreen onLogin={() => setIsLoggedIn(true)} />;
  }

  const handleLogout = () => {
    localStorage.removeItem("admin_token");
    localStorage.removeItem("admin_email");
    setIsLoggedIn(false);
  };

  const renderSection = () => {

    switch (section) {
      case "departments": return <DepartmentsSection />;
      case "batches": return <BatchesSection />;
      case "classes": return <ClassesSection />;
      case "students": return <StudentsSection />;
      case "teachers": return <TeachersSection />;
      case "subjects": return <SubjectsSection />;
      case "teacher-subjects": return <TeacherSubjectSection />;
      case "class-subjects": return <ClassSubjectSection />;
      case "timetable": return <TimetableSection />;
      case "faces": return <FaceEnrollmentSection />;
      case "marks": return <MarksConfigSection />;
      case "profiles": return <StudentProfileSection />;
      case "attendance": return <AttendanceSection />;
      case "users": return <UsersSection />;
      default: return null;
    }
  };

  return (
    <div className="app-container">
      <aside className="sidebar">
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", paddingRight: "10px" }}>
          <h1>🎓 Smart Attendance</h1>
        </div>

        <div className="nav-section-title">College Structure</div>
        <button className={"nav-button " + (section === "departments" ? "active" : "")} onClick={() => setSection("departments")}>📚 Departments</button>
        <button className={"nav-button " + (section === "batches" ? "active" : "")} onClick={() => setSection("batches")}>📅 Batches</button>
        <button className={"nav-button " + (section === "classes" ? "active" : "")} onClick={() => setSection("classes")}>🏫 Classes</button>
        <div className="nav-section-title">Users</div>
        <button className={"nav-button " + (section === "students" ? "active" : "")} onClick={() => setSection("students")}>👨‍🎓 Students</button>
        <button className={"nav-button " + (section === "teachers" ? "active" : "")} onClick={() => setSection("teachers")}>👨‍🏫 Teachers</button>
        <button className={"nav-button " + (section === "users" ? "active" : "")} onClick={() => setSection("users")}>🔐 Credentials</button>

        <div className="nav-section-title">Subjects & Mapping</div>
        <button className={"nav-button " + (section === "subjects" ? "active" : "")} onClick={() => setSection("subjects")}>📖 Subjects</button>
        <button className={"nav-button " + (section === "teacher-subjects" ? "active" : "")} onClick={() => setSection("teacher-subjects")}>🔗 Teacher-Subject</button>
        <button className={"nav-button " + (section === "class-subjects" ? "active" : "")} onClick={() => setSection("class-subjects")}>🔗 Class-Subject</button>
        <button className={"nav-button " + (section === "timetable" ? "active" : "")} onClick={() => setSection("timetable")}>📅 Timetable</button>
        <div className="nav-section-title">AI Face Recognition</div>
        <button className={"nav-button " + (section === "faces" ? "active" : "")} onClick={() => setSection("faces")}>🤖 Face Enrollment</button>

        <div className="nav-section-title">Grading & Attendance</div>
        <button className={"nav-button " + (section === "marks" ? "active" : "")} onClick={() => setSection("marks")}>📊 Marks Config</button>
        <button className={"nav-button " + (section === "attendance" ? "active" : "")} onClick={() => setSection("attendance")}>📋 Attendance Viewer</button>

        <div className="nav-section-title">Profiles</div>
        <button className={"nav-button " + (section === "profiles" ? "active" : "")} onClick={() => setSection("profiles")}>👤 Student Profiles</button>


        <div style={{ marginTop: "auto", paddingTop: "20px", borderTop: "1px solid rgba(255,255,255,0.1)" }}>
          <button className="nav-button" onClick={handleLogout} style={{ color: "#ff6b6b" }}>🚪 Logout</button>
        </div>
      </aside>
      <main className="content">{renderSection()}</main>
    </div>
  );
}

// =============================================
// TIMETABLE SECTION
// =============================================

function TimetableSection() {
  const [viewMode, setViewMode] = React.useState("teacher"); // 'teacher' or 'class'
  const [selectedId, setSelectedId] = React.useState("");

  // Load lookup data
  const { items: teachers } = useFetchList(`${API_BASE}/admin/teachers`);
  const { items: classes } = useFetchList(`${API_BASE}/admin/classes`);
  const { items: subjects } = useFetchList(`${API_BASE}/admin/subjects`);
  // Load mappings for filtering
  const { items: teacherSubjects } = useFetchList(`${API_BASE}/admin/teacher-subjects`);
  const { items: classSubjects } = useFetchList(`${API_BASE}/admin/class-subjects`);

  const [timetable, setTimetable] = React.useState([]);
  const [loading, setLoading] = React.useState(false);
  const { notification, showSuccess, showError } = useNotification();

  // Modal State
  const [editCell, setEditCell] = React.useState(null); // { day, period, currentVal }
  const [editClass, setEditClass] = React.useState("");
  const [editTeacher, setEditTeacher] = React.useState("");
  const [editSubject, setEditSubject] = React.useState("");
  const [saving, setSaving] = React.useState(false);

  // Fetch timetable when selection changes
  React.useEffect(() => {
    if (!selectedId) {
      setTimetable([]);
      return;
    }
    const fetchTimetable = async () => {
      setLoading(true);
      try {
        const type = viewMode === "teacher" ? "teacher" : "class";
        const res = await authFetch(`${API_BASE}/admin/timetable/${type}/${selectedId}`);
        if (!res.ok) throw new Error(await res.text());
        setTimetable(await res.json());
      } catch (e) {
        showError("Failed to load: " + e.message);
      } finally {
        setLoading(false);
      }
    };
    fetchTimetable();
  }, [viewMode, selectedId]);

  // Transform list to grid map
  const getCell = (day, period) => {
    return timetable.find(t => t.day === day && t.period === period);
  };

  const handleCellClick = (day, period) => {
    if (!selectedId) return;
    const entry = getCell(day, period);
    setEditCell({ day, period });

    // Pre-fill if exists
    if (entry) {
      setEditClass(entry.class_id);
      setEditTeacher(entry.teacher_id);
      setEditSubject(entry.subject_code);
    } else {
      // Default to current selection context
      if (viewMode === "teacher") setEditTeacher(selectedId);
      if (viewMode === "class") setEditClass(selectedId);
      setEditSubject("");
      // If viewMode is teacher, class is blank. If viewMode is class, teacher is blank.
      if (viewMode === "teacher" && !entry) setEditClass("");
      if (viewMode === "class" && !entry) setEditTeacher("");
    }
  };

  const saveCell = async (e) => {
    e.preventDefault();
    if (!editSubject) return;
    if (viewMode === "teacher" && !editClass) { showError("Select Class"); return; }
    if (viewMode === "class" && !editTeacher) { showError("Select Teacher"); return; }

    try {
      setSaving(true);
      // Payload
      const payload = {
        day: editCell.day,
        period: editCell.period,
        subject_code: editSubject,
        class_id: viewMode === "teacher" ? editClass : selectedId,
        teacher_id: Number(viewMode === "class" ? editTeacher : selectedId)
      };

      const res = await authFetch(`${API_BASE}/admin/timetable`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload)
      });

      if (!res.ok) throw new Error(await res.text());

      showSuccess("Saved!");
      setEditCell(null);

      // Refresh
      const type = viewMode === "teacher" ? "teacher" : "class";
      const refreshRes = await authFetch(`${API_BASE}/admin/timetable/${type}/${selectedId}`);
      setTimetable(await refreshRes.json());

    } catch (e) {
      showError(e.message);
    } finally {
      setSaving(false);
    }
  };

  const DAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  const PERIODS = [1, 2, 3, 4, 5, 6, 7];

  return (
    <div className="card">
      <div className="card-header">
        <div>
          <div className="card-title">Timetable Management</div>
          <div className="card-subtitle">Assign classes and teachers to slots</div>
        </div>
      </div>

      {notification && <div className={`alert alert-${notification.type}`}>{notification.message}</div>}

      {/* Controls */}
      <div className="form-grid" style={{ marginBottom: "20px", borderBottom: "1px solid rgba(255,255,255,0.1)", paddingBottom: "20px" }}>
        <div className="field">
          <label>View Mode</label>
          <div style={{ display: "flex", gap: "10px" }}>
            <button className={viewMode === "teacher" ? "primary-button" : "secondary-button"} onClick={() => { setViewMode("teacher"); setSelectedId(""); }}>By Teacher</button>
            <button className={viewMode === "class" ? "primary-button" : "secondary-button"} onClick={() => { setViewMode("class"); setSelectedId(""); }}>By Class</button>
          </div>
        </div>

        <div className="field">
          <label>{viewMode === "teacher" ? "Select Teacher" : "Select Class"}</label>
          <select value={selectedId} onChange={e => setSelectedId(e.target.value)}>
            <option value="">Select...</option>
            {viewMode === "teacher"
              ? teachers.map(t => <option key={t.teacher_id} value={t.teacher_id}>{t.employee_no} - {t.name}</option>)
              : classes.map(c => <option key={c.class_id} value={c.class_id}>Class {c.class_id} (Y{c.year}-{c.section})</option>)
            }
          </select>
        </div>
      </div>

      {/* Grid */}
      {selectedId && (
        <div style={{ overflowX: "auto" }}>
          {loading ? <div>Loading...</div> : (
            <table className="table timetable-table">
              <thead>
                <tr>
                  <th style={{ width: "80px" }}>Day</th>
                  {PERIODS.map(p => <th key={p} style={{ width: "120px" }}>P{p}</th>)}
                </tr>
              </thead>
              <tbody>
                {DAYS.map(day => (
                  <tr key={day}>
                    <td style={{ fontWeight: "bold" }}>{day}</td>
                    {PERIODS.map(period => {
                      const entry = getCell(day, period);
                      return (
                        <td key={period}
                          onClick={() => handleCellClick(day, period)}
                          style={{ cursor: "pointer", background: entry ? "rgba(76, 175, 80, 0.1)" : "transparent", border: entry ? "1px solid rgba(76, 175, 80, 0.3)" : "1px solid rgba(255,255,255,0.05)" }}>
                          {entry ? (
                            <div style={{ fontSize: "11px", textAlign: "center" }}>
                              {viewMode === "teacher"
                                ? <>{entry.class_id}<br /><span style={{ opacity: 0.7 }}>{entry.subject_code}</span></>
                                : <>{entry.subject_code}<br /><span style={{ opacity: 0.7 }}>{teachers.find(t => t.teacher_id === entry.teacher_id)?.name || entry.teacher_id}</span></>
                              }
                            </div>
                          ) : (
                            <div style={{ color: "#444", fontSize: "11px", textAlign: "center" }}>Free</div>
                          )}
                        </td>
                      );
                    })}
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      )}

      {/* Edit Modal */}
      {editCell && (
        <div style={{ position: "fixed", top: 0, left: 0, right: 0, bottom: 0, background: "rgba(0,0,0,0.8)", display: "flex", alignItems: "center", justifyContent: "center", zIndex: 1000 }}>
          <div className="card" style={{ maxWidth: "400px", width: "90%" }}>
            <div className="card-header">
              <div className="card-title">Edit Slot</div>
              <div className="card-subtitle">{editCell.day} - Period {editCell.period}</div>
            </div>

            <form onSubmit={saveCell}>
              <div className="form-grid">
                {/* Depends on View Mode */}
                {viewMode === "teacher" ? (
                  // Teacher View: Need Class + Subject
                  <>
                    <div className="field">
                      <label>Class</label>
                      <select value={editClass} onChange={e => setEditClass(e.target.value)} required>
                        <option value="">Select Class...</option>
                        {classes.map(c => <option key={c.class_id} value={c.class_id}>Class {c.class_id} (Y{c.year}-{c.section})</option>)}
                      </select>
                    </div>
                  </>
                ) : (
                  // Class View: Need Teacher + Subject
                  <>
                    <div className="field">
                      <label>Teacher</label>
                      <select value={editTeacher} onChange={e => setEditTeacher(e.target.value)} required>
                        <option value="">Select Teacher...</option>
                        {teachers.map(t => <option key={t.teacher_id} value={t.teacher_id}>{t.employee_no} - {t.name}</option>)}
                      </select>
                    </div>
                  </>
                )}

                <div className="field">
                  <label>Subject</label>
                  <select value={editSubject} onChange={e => setEditSubject(e.target.value)} required>
                    <option value="">Select Subject...</option>
                    {subjects
                      .filter(s => {
                        // Logic: Subject must be valid for BOTH the selected Teacher AND the selected Class.

                        // 1. Identify context
                        const currentTeacherId = viewMode === "teacher" ? Number(selectedId) : Number(editTeacher);
                        const currentClassId = viewMode === "class" ? selectedId : editClass;

                        if (!currentTeacherId || !currentClassId) return true; // Show all if selection incomplete

                        // 2. Check Teacher Mapping
                        // Does this teacher teach this subject?
                        const teacherHasSubject = teacherSubjects.some(m => m.teacher_id === currentTeacherId && m.subject_code === s.subject_code);

                        // 3. Check Class Mapping
                        // Is this subject assigned to this class?
                        const classHasSubject = classSubjects.some(m => m.class_id === currentClassId && m.subject_code === s.subject_code);

                        return teacherHasSubject && classHasSubject;
                      })
                      .map(s => <option key={s.subject_code} value={s.subject_code}>{s.subject_code} - {s.subject_name}</option>)
                    }
                  </select>
                  {/* Explanation helper */}
                  <div style={{ fontSize: "10px", color: "#888", marginTop: "4px" }}>
                    Only showing subjects mapped to both the selected Teacher AND Class.
                  </div>
                </div>
              </div>

              <div style={{ display: "flex", gap: "10px", marginTop: "20px" }}>
                <button type="submit" className="primary-button" disabled={saving}>{saving ? "Saving..." : "Save Assignment"}</button>
                <button type="button" className="secondary-button" onClick={() => setEditCell(null)}>Cancel</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

const root = ReactDOM.createRoot(document.getElementById("root"));
root.render(<App />);
