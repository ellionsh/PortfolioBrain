from agent.agent import agent_chat

def main():
    print("PortfolioBrain CLI")
    print("输入 exit 退出")
    while True:
        q = input("你：")
        if q.strip().lower() == "exit":
            break
        print("AI：", agent_chat(q))

if __name__ == "__main__":
    main()
