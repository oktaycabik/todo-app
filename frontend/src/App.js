import React, { useState, useEffect } from 'react';
import axios from 'axios';
import './App.css';

function App() {
  const [todos, setTodos] = useState([]);
  const [newTodo, setNewTodo] = useState('');
  const API_URL = process.env.REACT_APP_API_URL;

  useEffect(() => {
    const fetchData = async () => {
      await fetchTodos();
    };
    fetchData();
  }, []);

  const fetchTodos = async () => {
    try {
      const response = await axios.get(`${API_URL}/todos`);
      setTodos(response.data);
    } catch (error) {
      console.error('Todo\'lar getirilemedi:', error);
    }
  };

  const addTodo = async (e) => {
    e.preventDefault();
    if (!newTodo.trim()) return;
    
    try {
      const response = await axios.post(`${API_URL}/todos`, {
        title: newTodo
      });
      setTodos([...todos, response.data]);
      setNewTodo('');
    } catch (error) {
      console.error('Todo eklenemedi:', error);
    }
  };

  return (
    <div className="container">
      <div className="todo-app">
        <h1>Retro Todo List</h1>
        <form onSubmit={addTodo} className="todo-form">
          <input
            type="text"
            value={newTodo}
            onChange={(e) => setNewTodo(e.target.value)}
            placeholder="Yeni görev ekle..."
            className="todo-input"
          />
          <button type="submit" className="add-button">EkleeEeeeeeee</button>
        </form>
        <div className="todo-list">
          {todos.map(todo => (
            <div key={todo.id} className="todo-item">
              <span className="todo-text">{todo.title}</span>
              <span className="todo-date">
                {new Date(todo.createdAt).toLocaleDateString('tr-TR')}
              </span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

export default App; 