(function(){
  function $(sel){ return document.querySelector(sel); }
  const list = $("#sortable-list");
  if(!list) return;

  let dragEl = null;
  list.addEventListener("dragstart", (e)=>{
    const li = e.target.closest("li[draggable=true]");
    if(!li) return;
    dragEl = li;
    e.dataTransfer.effectAllowed = "move";
    e.dataTransfer.setData("text/plain", li.dataset.id);
    li.classList.add("opacity-50");
  });
  list.addEventListener("dragend", (e)=>{
    if(dragEl) dragEl.classList.remove("opacity-50");
    dragEl = null;
  });
  list.addEventListener("dragover", (e)=>{
    e.preventDefault();
    const li = e.target.closest("li[draggable=true]");
    if(!li || li===dragEl) return;
    const rect = li.getBoundingClientRect();
    const before = (e.clientY - rect.top) < rect.height/2;
    list.insertBefore(dragEl, before ? li : li.nextSibling);
  });
  list.addEventListener("drop", (e)=>{
    e.preventDefault();
    saveOrder();
  });

  function saveOrder(){
    const ids = Array.from(list.querySelectorAll("li[draggable=true]"))
                .map(li => parseInt(li.dataset.id,10));
    const status = document.getElementById("save-status");
    const meta = document.querySelector('meta[name="csrf-token"]');
    const csrf = meta ? meta.getAttribute("content") : "";

    // Infer reorder URL from the first "Edit" link (same menu scope)
    const editLink = list.querySelector('a[href*="/settings/dropdowns/"][href*="/items/"]');
    if(!editLink){ return; }
    const m = editLink.href.match(/^(https?:\/\/[^/]+)?\/settings\/dropdowns\/(\d+)/);
    if(!m){ return; }
    const menuId = m[2];
    const url = `/settings/dropdowns/${menuId}/items/reorder`;

    fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-TOKEN": csrf,
        "Accept": "application/json"
      },
      body: JSON.stringify({order: ids})
    })
    .then(r => r.json())
    .then(j => {
      if(j && j.ok){
        status.className = "mt-3 text-sm text-green-700";
        status.textContent = "Order saved.";
      }else{
        status.className = "mt-3 text-sm text-red-700";
        status.textContent = "Failed to save order.";
      }
      setTimeout(()=>{ status.classList.add("hidden"); }, 1500);
      status.classList.remove("hidden");
    })
    .catch(()=> {
      status.className = "mt-3 text-sm text-red-700";
      status.textContent = "Failed to save order.";
      status.classList.remove("hidden");
      setTimeout(()=>{ status.classList.add("hidden"); }, 2000);
    });
  }
})();
