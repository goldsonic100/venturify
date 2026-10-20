/* Venturify collaboration task checklist interactions.
   Loaded after workspace.html's main script so it can use the existing workspace state. */
(function () {
  const taskList = document.getElementById('tasks');
  if (!taskList) return;

  taskList.addEventListener('change', async (event) => {
    const checkbox = event.target.closest('[data-checklist-toggle]');
    if (!checkbox) return;
    const item = (taskChecklistItemsCache || []).find(row => row.id === checkbox.dataset.checklistToggle);
    if (!item || !workspace) return;
    const previous = item.is_complete;
    checkbox.disabled = true;
    const result = await db.from('workspace_task_checklist_items')
      .update({ is_complete: checkbox.checked, updated_at: new Date().toISOString() })
      .eq('id', item.id).eq('workspace_id', workspace.id);
    if (result.error) {
      checkbox.checked = previous;
      checkbox.disabled = false;
      note('Could not update checklist item. Try again.', true);
      return;
    }
    await loadTasks();
    await loadActivity();
  });

  taskList.addEventListener('click', async (event) => {
    const add = event.target.closest('[data-checklist-add]');
    if (add) {
      const task = taskRowsCache.find(row => row.id === add.dataset.checklistAdd);
      if (!task || !workspace) return;
      const title = prompt('Checklist item (up to 240 characters):');
      if (title === null) return;
      if (!title.trim()) { note('Checklist item cannot be empty.', true); return; }
      const position = taskChecklistItemsCache.filter(row => row.task_id === task.id).length;
      add.disabled = true;
      const result = await db.from('workspace_task_checklist_items').insert({
        workspace_id: workspace.id, task_id: task.id, title: title.trim().slice(0, 240),
        created_by: user.id, position
      });
      add.disabled = false;
      if (result.error) { note('Could not add checklist item. Check your connection and try again.', true); return; }
      await loadTasks();
      await loadActivity();
      return;
    }

    const edit = event.target.closest('[data-checklist-edit]');
    if (edit) {
      const item = taskChecklistItemsCache.find(row => row.id === edit.dataset.checklistEdit);
      if (!item || !workspace) return;
      const title = prompt('Rename checklist item:', item.title);
      if (title === null) return;
      if (!title.trim()) { note('Checklist item cannot be empty.', true); return; }
      edit.disabled = true;
      const result = await db.from('workspace_task_checklist_items')
        .update({ title: title.trim().slice(0, 240), updated_at: new Date().toISOString() })
        .eq('id', item.id).eq('workspace_id', workspace.id);
      edit.disabled = false;
      if (result.error) { note('Could not rename checklist item.', true); return; }
      await loadTasks();
      await loadActivity();
      return;
    }

    const remove = event.target.closest('[data-checklist-delete]');
    if (remove) {
      const item = taskChecklistItemsCache.find(row => row.id === remove.dataset.checklistDelete);
      if (!item || !workspace || !confirm('Remove checklist item "' + item.title + '"?')) return;
      remove.disabled = true;
      const result = await db.from('workspace_task_checklist_items').delete()
        .eq('id', item.id).eq('workspace_id', workspace.id);
      if (result.error) { note('Could not remove checklist item.', true); remove.disabled = false; return; }
      await loadTasks();
      await loadActivity();
    }
  });

  const priorityFilter = document.getElementById('taskPriorityFilter');
  const checklistFilter = document.getElementById('taskChecklistFilter');
  const labelFilter = document.getElementById('taskLabelFilter');
  if (priorityFilter) priorityFilter.addEventListener('change', () => {
    taskPriorityFilter = priorityFilter.value;
    applyChecklistFilters();
  });
  if (checklistFilter) checklistFilter.addEventListener('change', () => {
    taskChecklistFilter = checklistFilter.value;
    applyChecklistFilters();
  });
  if (labelFilter) labelFilter.addEventListener('input', () => {
    taskLabelFilter = labelFilter.value.trim().toLowerCase();
    applyChecklistFilters();
  });

  const originalRenderTasks = renderTasks;
  function applyChecklistFilters() {
    originalRenderTasks();
    const cards = taskList.querySelectorAll('article.task');
    cards.forEach(card => {
      const title = card.querySelector('h3')?.textContent || '';
      const task = taskRowsCache.find(row => row.title === title);
      if (!task) return;
      const items = taskChecklistItemsCache.filter(row => row.task_id === task.id);
      const priorityOk = taskPriorityFilter === 'any' || (task.priority || 'medium') === taskPriorityFilter;
      const labels = (task.labels || '').toLowerCase().split(',').map(label => label.trim());
      const labelOk = !taskLabelFilter || labels.some(label => label.includes(taskLabelFilter));
      const checklistOk = taskChecklistFilter === 'any' ||
        (taskChecklistFilter === 'none' && items.length === 0) ||
        (taskChecklistFilter === 'complete' && items.length > 0 && items.every(row => row.is_complete)) ||
        (taskChecklistFilter === 'incomplete' && items.some(row => !row.is_complete));
      card.hidden = !(priorityOk && labelOk && checklistOk);
    });
  }
})();