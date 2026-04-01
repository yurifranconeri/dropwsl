
@app.post("/items", response_model=ItemResponse, status_code=201)
def create_item(
    data: ItemCreate, session: Session = Depends(get_session),
) -> ItemModel:
    """Creates a new item."""
    return service.create_item(session, name=data.name, description=data.description)


@app.get("/items/{item_id}", response_model=ItemResponse)
def read_item(
    item_id: int, session: Session = Depends(get_session),
) -> ItemModel:
    """Gets item by ID."""
    item = service.get_item(session, item_id)
    if item is None:
        raise HTTPException(status_code=404, detail="Item not found")
    return item


@app.get("/items", response_model=list[ItemResponse])
def list_items(session: Session = Depends(get_session)) -> list[ItemModel]:
    """Lists all items."""
    return service.list_items(session)


@app.delete("/items/{item_id}", status_code=204)
def delete_item(
    item_id: int, session: Session = Depends(get_session),
) -> None:
    """Deletes item by ID."""
    if not service.delete_item(session, item_id):
        raise HTTPException(status_code=404, detail="Item not found")

